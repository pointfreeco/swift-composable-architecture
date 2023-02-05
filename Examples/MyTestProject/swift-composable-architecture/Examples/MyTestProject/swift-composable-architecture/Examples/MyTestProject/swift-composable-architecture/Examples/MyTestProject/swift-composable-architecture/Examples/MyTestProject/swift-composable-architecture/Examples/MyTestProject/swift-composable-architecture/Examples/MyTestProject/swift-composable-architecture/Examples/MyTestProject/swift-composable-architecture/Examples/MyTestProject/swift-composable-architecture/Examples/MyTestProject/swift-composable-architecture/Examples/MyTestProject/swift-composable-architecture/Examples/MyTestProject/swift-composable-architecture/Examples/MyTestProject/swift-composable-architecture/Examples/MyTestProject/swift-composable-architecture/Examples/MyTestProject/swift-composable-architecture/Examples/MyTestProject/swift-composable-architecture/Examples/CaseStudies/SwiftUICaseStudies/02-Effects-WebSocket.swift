import ComposableArchitecture
import SwiftUI
import XCTestDynamicOverlay

private let readMe = """
  This application demonstrates how to work with a web socket in the Composable Architecture.

  A lightweight wrapper is made for `URLSession`'s API for web sockets so that we can send, \
  receive and ping a socket endpoint. To test, connect to the socket server, and then send a \
  message. The socket server should immediately reply with the exact message you sent in.
  """

// MARK: - Feature domain

struct WebSocket: ReducerProtocol {
  struct State: Equatable {
    var alert: AlertState<Action>?
    var connectivityState = ConnectivityState.disconnected
    var messageToSend = ""
    var receivedMessages: [String] = []

    enum ConnectivityState: String {
      case connected
      case connecting
      case disconnected
    }
  }

  enum Action: Equatable {
    case alertDismissed
    case connectButtonTapped
    case messageToSendChanged(String)
    case receivedSocketMessage(TaskResult<WebSocketClient.Message>)
    case sendButtonTapped
    case sendResponse(didSucceed: Bool)
    case webSocket(WebSocketClient.Action)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.webSocket) var webSocket
  private enum WebSocketID {}

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .alertDismissed:
      state.alert = nil
      return .none

    case .connectButtonTapped:
      switch state.connectivityState {
      case .connected, .connecting:
        state.connectivityState = .disconnected
        return .cancel(id: WebSocketID.self)

      case .disconnected:
        state.connectivityState = .connecting
        return .run { send in
          let actions = await self.webSocket
            .open(WebSocketID.self, URL(string: "wss://echo.websocket.events")!, [])
          await withThrowingTaskGroup(of: Void.self) { group in
            for await action in actions {
              // NB: Can't call `await send` here outside of `group.addTask` due to task local
              //     dependency mutation in `Effect.{task,run}`. Can maybe remove that explicit task
              //     local mutation (and this `addTask`?) in a world with
              //     `Effect(operation: .run { ... })`?
              group.addTask { await send(.webSocket(action)) }
              switch action {
              case .didOpen:
                group.addTask {
                  while !Task.isCancelled {
                    try await self.clock.sleep(for: .seconds(10))
                    try? await self.webSocket.sendPing(WebSocketID.self)
                  }
                }
                group.addTask {
                  for await result in try await self.webSocket.receive(WebSocketID.self) {
                    await send(.receivedSocketMessage(result))
                  }
                }
              case .didClose:
                return
              }
            }
          }
        }
        .cancellable(id: WebSocketID.self)
      }

    case let .messageToSendChanged(message):
      state.messageToSend = message
      return .none

    case let .receivedSocketMessage(.success(message)):
      if case let .string(string) = message {
        state.receivedMessages.append(string)
      }
      return .none

    case .receivedSocketMessage(.failure):
      return .none

    case .sendButtonTapped:
      let messageToSend = state.messageToSend
      state.messageToSend = ""
      return .task {
        try await self.webSocket.send(WebSocketID.self, .string(messageToSend))
        return .sendResponse(didSucceed: true)
      } catch: { _ in
        .sendResponse(didSucceed: false)
      }
      .cancellable(id: WebSocketID.self)

    case .sendResponse(didSucceed: false):
      state.alert = AlertState {
        TextState("Could not send socket message. Connect to the server first, and try again.")
      }
      return .none

    case .sendResponse(didSucceed: true):
      return .none

    case .webSocket(.didClose):
      state.connectivityState = .disconnected
      return .cancel(id: WebSocketID.self)

    case .webSocket(.didOpen):
      state.connectivityState = .connected
      state.receivedMessages.removeAll()
      return .none
    }
  }
}

// MARK: - Feature view

struct WebSocketView: View {
  let store: StoreOf<WebSocket>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        Section {
          VStack(alignment: .leading) {
            Button(
              viewStore.connectivityState == .connected
                ? "Disconnect"
                : viewStore.connectivityState == .disconnected
                  ? "Connect"
                  : "Connecting..."
            ) {
              viewStore.send(.connectButtonTapped)
            }
            .buttonStyle(.bordered)
            .tint(viewStore.connectivityState == .connected ? .red : .green)

            HStack {
              TextField(
                "Type message here",
                text: viewStore.binding(
                  get: \.messageToSend, send: WebSocket.Action.messageToSendChanged)
              )
              .textFieldStyle(.roundedBorder)

              Button("Send") {
                viewStore.send(.sendButtonTapped)
              }
              .buttonStyle(.borderless)
            }
          }
        }

        Section {
          Text("Status: \(viewStore.connectivityState.rawValue)")
            .foregroundStyle(.secondary)
          Text(viewStore.receivedMessages.reversed().joined(separator: "\n"))
        } header: {
          Text("Received messages")
        }
      }
      .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
      .navigationTitle("Web Socket")
    }
  }
}

// MARK: - WebSocketClient

struct WebSocketClient {
  enum Action: Equatable {
    case didOpen(protocol: String?)
    case didClose(code: URLSessionWebSocketTask.CloseCode, reason: Data?)
  }

  enum Message: Equatable {
    struct Unknown: Error {}

    case data(Data)
    case string(String)

    init(_ message: URLSessionWebSocketTask.Message) throws {
      switch message {
      case let .data(data): self = .data(data)
      case let .string(string): self = .string(string)
      @unknown default: throw Unknown()
      }
    }
  }

  var open: @Sendable (Any.Type, URL, [String]) async -> AsyncStream<Action>
  var receive: @Sendable (Any.Type) async throws -> AsyncStream<TaskResult<Message>>
  var send: @Sendable (Any.Type, URLSessionWebSocketTask.Message) async throws -> Void
  var sendPing: @Sendable (Any.Type) async throws -> Void
}

extension WebSocketClient: DependencyKey {
  static var liveValue: Self {
    return Self(
      open: { await WebSocketActor.shared.open(id: $0, url: $1, protocols: $2) },
      receive: { try await WebSocketActor.shared.receive(id: $0) },
      send: { try await WebSocketActor.shared.send(id: $0, message: $1) },
      sendPing: { try await WebSocketActor.shared.sendPing(id: $0) }
    )

    final actor WebSocketActor: GlobalActor {
      final class Delegate: NSObject, URLSessionWebSocketDelegate {
        var continuation: AsyncStream<Action>.Continuation?

        func urlSession(
          _: URLSession,
          webSocketTask _: URLSessionWebSocketTask,
          didOpenWithProtocol protocol: String?
        ) {
          self.continuation?.yield(.didOpen(protocol: `protocol`))
        }

        func urlSession(
          _: URLSession,
          webSocketTask _: URLSessionWebSocketTask,
          didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
          reason: Data?
        ) {
          self.continuation?.yield(.didClose(code: closeCode, reason: reason))
          self.continuation?.finish()
        }
      }

      typealias Dependencies = (socket: URLSessionWebSocketTask, delegate: Delegate)

      static let shared = WebSocketActor()

      var dependencies: [ObjectIdentifier: Dependencies] = [:]

      func open(id: Any.Type, url: URL, protocols: [String]) -> AsyncStream<Action> {
        let id = ObjectIdentifier(id)
        let delegate = Delegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let socket = session.webSocketTask(with: url, protocols: protocols)
        defer { socket.resume() }
        var continuation: AsyncStream<Action>.Continuation!
        let stream = AsyncStream<Action> {
          $0.onTermination = { _ in
            socket.cancel()
            Task { await self.removeDependencies(id: id) }
          }
          continuation = $0
        }
        delegate.continuation = continuation
        self.dependencies[id] = (socket, delegate)
        return stream
      }

      func close(
        id: Any.Type, with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
      ) async throws {
        let id = ObjectIdentifier(id)
        defer { self.dependencies[id] = nil }
        try self.socket(id: id).cancel(with: closeCode, reason: reason)
      }

      func receive(id: Any.Type) throws -> AsyncStream<TaskResult<Message>> {
        let socket = try self.socket(id: ObjectIdentifier(id))
        return AsyncStream { continuation in
          let task = Task {
            while !Task.isCancelled {
              continuation.yield(await TaskResult { try await Message(socket.receive()) })
            }
            continuation.finish()
          }
          continuation.onTermination = { _ in task.cancel() }
        }
      }

      func send(id: Any.Type, message: URLSessionWebSocketTask.Message) async throws {
        try await self.socket(id: ObjectIdentifier(id)).send(message)
      }

      func sendPing(id: Any.Type) async throws {
        let socket = try self.socket(id: ObjectIdentifier(id))
        return try await withCheckedThrowingContinuation { continuation in
          socket.sendPing { error in
            if let error = error {
              continuation.resume(throwing: error)
            } else {
              continuation.resume()
            }
          }
        }
      }

      private func socket(id: ObjectIdentifier) throws -> URLSessionWebSocketTask {
        guard let dependencies = self.dependencies[id]?.socket else {
          struct Closed: Error {}
          throw Closed()
        }
        return dependencies
      }

      private func removeDependencies(id: ObjectIdentifier) {
        self.dependencies[id] = nil
      }
    }
  }

  static let testValue = Self(
    open: unimplemented("\(Self.self).open", placeholder: AsyncStream.never),
    receive: unimplemented("\(Self.self).receive"),
    send: unimplemented("\(Self.self).send"),
    sendPing: unimplemented("\(Self.self).sendPing")
  )
}

extension DependencyValues {
  var webSocket: WebSocketClient {
    get { self[WebSocketClient.self] }
    set { self[WebSocketClient.self] = newValue }
  }
}

// MARK: - SwiftUI previews

struct WebSocketView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      WebSocketView(
        store: Store(
          initialState: WebSocket.State(receivedMessages: ["Hi"]),
          reducer: WebSocket()
        )
      )
    }
  }
}
