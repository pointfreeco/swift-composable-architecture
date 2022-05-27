import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates how to work with a web socket in the Composable Architecture.

  A lightweight wrapper is made for `URLSession`'s API for web sockets so that we can send, \
  receive and ping a socket endpoint. To test, connect to the socket server, and then send a \
  message. The socket server should immediately reply with the exact message you send it.
  """

struct WebSocketState: Equatable {
  var alert: AlertState<WebSocketAction>?
  var connectivityState = ConnectivityState.disconnected
  var handle: WebSocketClient.Handle?
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
  case pong(TaskResult<EquatableVoid>)
  case receivedHandle(WebSocketClient.Handle)
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
      guard let handle = state.handle else { return .none }
      return .fireAndForget { @MainActor in
        try await environment.webSocket.close(handle, .normalClosure, nil)
      }

    case .disconnected:
      state.connectivityState = .connecting
      return .run { @MainActor send in
        let (handle, actions) = await environment.webSocket
          .open(URL(string: "wss://echo.websocket.events")!, [])
        send(.receivedHandle(handle))
        for await action in actions {
          send(.webSocket(action))
        }
      }
      .cancellable(id: WebSocketId.self)
    }

  case let .messageToSendChanged(message):
    state.messageToSend = message
    return .none

  case .pong:
    guard let handle = state.handle else { return .none }
    return .task {
      .pong(await .init { try await environment.webSocket.sendPing(handle) })
    }
    .delay(for: 10, scheduler: environment.mainQueue)  // TODO: 'Clock'
    .eraseToEffect()
    .cancellable(id: WebSocketId.self)

  case let .receivedHandle(handle):
    state.handle = handle
    return .none

  case let .receivedSocketMessage(.success(message)):
    if case let .string(string) = message {
      state.receivedMessages.append(string)
    }
    guard let handle = state.handle else { return .none }
    return .task { @MainActor in
      .receivedSocketMessage(await .init { try await environment.webSocket.receive(handle) })
    }
    .cancellable(id: WebSocketId.self)

  case .receivedSocketMessage(.failure(_)):
    return .none

  case .sendButtonTapped:
    guard let handle = state.handle else { return .none }
    let messageToSend = state.messageToSend
    state.messageToSend = ""
    return .task { @MainActor in
      .sendResponse(await .init {
        try await environment.webSocket.send(handle, .string(messageToSend))
      })
    }
    .cancellable(id: WebSocketId.self)

  case .sendResponse(.failure):
    state.alert = .init(title: .init("Could not send socket message. Try again."))
    return .none

  case .sendResponse(.success):
    return .none

  case .webSocket(.didOpen):
    guard let handle = state.handle else { return .none }
    state.connectivityState = .connected
    return .run { @MainActor send in
      send(.pong(.success(.init())))
      send(.receivedSocketMessage(await .init { try await environment.webSocket.receive(handle) }))
    }
    .cancellable(id: WebSocketId.self)

  case .webSocket(.didClose):
    state.connectivityState = .disconnected
    state.handle = nil
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

  struct Handle: Equatable, Hashable, @unchecked Sendable {
    struct Closed: Error {}

    var id = UUID()
  }

  enum Message: Equatable {
    case data(Data)
    case string(String)

    struct Unknown: Error {}

    init(_ message: URLSessionWebSocketTask.Message) throws {
      switch message {
      case let .data(data): self = .data(data)
      case let .string(string): self = .string(string)
      @unknown default: throw Unknown()
      }
    }
  }

  var close: @Sendable (Handle, URLSessionWebSocketTask.CloseCode, Data?) async throws -> Void
  var open: @Sendable (URL, [String]) async -> (handle: Handle, actions: AsyncStream<Action>)
  var receive: @Sendable (Handle) async throws -> Message
  var send: @Sendable (Handle, URLSessionWebSocketTask.Message) async throws -> Void
  var sendPing: @Sendable (Handle) async throws -> Void
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
        }
      }

      typealias Dependencies = (socket: URLSessionWebSocketTask, delegate: Delegate)

      static let shared = WebSocketActor()

      var dependencies: [Handle: Dependencies] = [:]

      func open(
        url: URL, protocols: [String]
      ) -> (handle: Handle, actions: AsyncStream<Action>) {
        let handle = Handle()
        let delegate = Delegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let socket = session.webSocketTask(with: url, protocols: protocols)
        defer { socket.resume() }
        var continuation: AsyncStream<Action>.Continuation!
        let stream = AsyncStream<Action> {
          $0.onTermination = { _ in
            socket.cancel()
            Task {
              try await WebSocketActor.shared
                .close(handle: handle, with: .abnormalClosure, reason: nil)
            }
          }
          continuation = $0
        }
        delegate.continuation = continuation
        self.dependencies[handle] = (socket, delegate)
        return (handle, stream)
      }

      func close(
        handle: Handle, with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
      ) async throws {
        defer { self.dependencies[handle] = nil }
        try self.dependencies(for: handle).socket.cancel(with: closeCode, reason: reason)
      }

      func receive(handle: Handle) async throws -> Message {
        try await Message(self.dependencies(for: handle).socket.receive())
      }

      func send(handle: Handle, message: URLSessionWebSocketTask.Message) async throws {
        try await self.dependencies(for: handle).socket.send(message)
      }

      func sendPing(handle: Handle) async throws {
        let socket = try self.dependencies(for: handle).socket
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

      private func dependencies(for handle: Handle) throws -> Dependencies {
        guard let dependencies = self.dependencies[handle] else { throw Handle.Closed() }
        return dependencies
      }
    }

    return Self(
      close: { try await WebSocketActor.shared.close(handle: $0, with: $1, reason: $2) },
      open: { await WebSocketActor.shared.open(url: $0, protocols: $1) },
      receive: { try await WebSocketActor.shared.receive(handle: $0) },
      send: { try await WebSocketActor.shared.send(handle: $0, message: $1) },
      sendPing: { try await WebSocketActor.shared.sendPing(handle: $0) }
    )
  }
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
