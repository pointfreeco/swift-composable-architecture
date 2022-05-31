import Combine
import ComposableArchitecture
import SwiftUI
import XCTestDynamicOverlay

private let readMe = """
  This application demonstrates how to work with a web socket in the Composable Architecture.

  A lightweight wrapper is made for `URLSession`'s API for web sockets so that we can send, \
  receive and ping a socket endpoint. To test, connect to the socket server, and then send a \
  message. The socket server should immediately reply with the exact message you send it.
  """

struct WebSocketState: Equatable {
  var alert: AlertState<WebSocketAction>?
  var connectivityState = ConnectivityState.disconnected
  var messageToSend = ""
  var receivedMessages: [String] = []

  enum ConnectivityState: String {
    case connected
    case connecting
    case disconnected
  }
}

enum WebSocketAction: Equatable {
  case alertDismissed
  case connectButtonTapped
  case messageToSendChanged(String)
  case receivedSocketMessage(TaskResult<WebSocketClient.Message>)
  case sendButtonTapped
  case sendResponse(TaskResult<EquatableVoid>)
  case webSocket(WebSocketClient.Action)
}

struct WebSocketEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var webSocket: WebSocketClient
}

let webSocketReducer = Reducer<WebSocketState, WebSocketAction, WebSocketEnvironment> {
  state, action, environment in

  enum WebSocketId {}

  switch action {
  case .alertDismissed:
    state.alert = nil
    return .none

  case .connectButtonTapped:
    switch state.connectivityState {
    case .connected, .connecting:
      state.connectivityState = .disconnected
      return .cancel(id: WebSocketId.self)

    case .disconnected:
      state.connectivityState = .connecting
      return .run { @MainActor send in
        let actions = await environment.webSocket
          .open(WebSocketId.self, URL(string: "wss://echo.websocket.events")!, [])
        await withThrowingTaskGroup(of: Void.self) { group in
          for await action in actions {
            send(.webSocket(action))
            switch action {
            case .didOpen:
              group.addTask {
                while !Task.isCancelled {
                  try await environment.mainQueue.sleep(for: .seconds(10))
                  try? await environment.webSocket.sendPing(WebSocketId.self)
                }
              }
              group.addTask { @MainActor in
                for await result in try await environment.webSocket.receive(WebSocketId.self) {
                  send(.receivedSocketMessage(result))
                }
              }
            case .didClose:
              return
            }
          }
        }
      }
      .cancellable(id: WebSocketId.self)
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
    return .task { @MainActor in
      .sendResponse(await .init {
        try await environment.webSocket.send(WebSocketId.self, .string(messageToSend))
      })
    }
    .cancellable(id: WebSocketId.self)

  case .sendResponse(.failure):
    state.alert = .init(title: .init("Could not send socket message. Try again."))
    return .none

  case .sendResponse(.success):
    return .none

  case .webSocket(.didClose):
    state.connectivityState = .disconnected
    return .none

  case .webSocket(.didOpen):
    state.connectivityState = .connected
    return .none
  }
}

struct WebSocketView: View {
  let store: Store<WebSocketState, WebSocketAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack(alignment: .leading) {
        Text(template: readMe, .body)
          .padding(.bottom)

        HStack {
          TextField(
            "Message to send",
            text: viewStore.binding(
              get: \.messageToSend, send: WebSocketAction.messageToSendChanged)
          )

          Button(
            viewStore.connectivityState == .connected
              ? "Disconnect"
              : viewStore.connectivityState == .disconnected
                ? "Connect"
                : "Connecting..."
          ) {
            viewStore.send(.connectButtonTapped)
          }
        }

        Button("Send message") {
          viewStore.send(.sendButtonTapped)
        }

        Spacer()

        Text("Status: \(viewStore.connectivityState.rawValue)")
          .foregroundColor(.secondary)
        Text("Received messages:")
          .foregroundColor(.secondary)
        Text(viewStore.receivedMessages.joined(separator: "\n"))
      }
      .padding()
      .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
      .navigationBarTitle("Web Socket")
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

extension WebSocketClient {
  static var live: Self {
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
        return .init { continuation in
          let task = Task {
            while !Task.isCancelled {
              continuation.yield(await .init { try await Message(socket.receive()) })
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

    return Self(
      open: { await WebSocketActor.shared.open(id: $0, url: $1, protocols: $2) },
      receive: { try await WebSocketActor.shared.receive(id: $0) },
      send: { try await WebSocketActor.shared.send(id: $0, message: $1) },
      sendPing: { try await WebSocketActor.shared.sendPing(id: $0) }
    )
  }
}

extension WebSocketClient {
  private struct Unimplemented: Error {
    let endpoint: String
    init(_ endpoint: String) {
      XCTFail(endpoint)
      self.endpoint = endpoint
    }
  }

  static let failing = Self(
    open: { _, _, _ in
      XCTFail("\(Self.self).open")
      return .init { _ in }
    },
    receive: { _ in throw Unimplemented("receive") },
    send: { _, _ in throw Unimplemented("send") },
    sendPing: { _ in throw Unimplemented("sendPing") }
  )
}

// MARK: - SwiftUI previews

struct WebSocketView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      WebSocketView(
        store: Store(
          initialState: .init(receivedMessages: ["Echo"]),
          reducer: webSocketReducer,
          environment: WebSocketEnvironment(
            mainQueue: .main,
            webSocket: .live
          )
        )
      )
    }
  }
}
