import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates how to work with a web socket in the Composable Architecture.

  A lightweight wrapper is made for `URLSession`'s API for web sockets so that we can send, \
  receive and ping a socket endpoint. To test, connect to the socket server, and then send a \
  message. The socket server should immediately reply with the exact message you send it.
  """

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
    case pingResponse(NSError?)
    case receivedSocketMessage(Result<WebSocketClient.Message, NSError>)
    case sendButtonTapped
    case sendResponse(NSError?)
    case webSocket(WebSocketClient.Action)
  }

  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.webSocket) var webSocket

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    struct WebSocketId: Hashable {}

    var receiveSocketMessageEffect: Effect<Action, Never> {
      self.webSocket.receive(WebSocketId())
        .receive(on: self.mainQueue)
        .catchToEffect(Action.receivedSocketMessage)
        .cancellable(id: WebSocketId())
    }
    var sendPingEffect: Effect<Action, Never> {
      self.webSocket.sendPing(WebSocketId())
        .delay(for: 10, scheduler: self.mainQueue)
        .map(Action.pingResponse)
        .eraseToEffect()
        .cancellable(id: WebSocketId())
    }

    switch action {
    case .alertDismissed:
      state.alert = nil
      return .none

    case .connectButtonTapped:
      switch state.connectivityState {
      case .connected, .connecting:
        state.connectivityState = .disconnected
        return .cancel(id: WebSocketId())

      case .disconnected:
        state.connectivityState = .connecting
        return self.webSocket.open(
          WebSocketId(), URL(string: "wss://echo.websocket.events")!, []
        )
        .receive(on: self.mainQueue)
        .map(Action.webSocket)
        .eraseToEffect()
        .cancellable(id: WebSocketId())
      }

    case let .messageToSendChanged(message):
      state.messageToSend = message
      return .none

    case .pingResponse:
      // Ping the socket again in 10 seconds
      return sendPingEffect

    case let .receivedSocketMessage(.success(.string(string))):
      state.receivedMessages.append(string)

      // Immediately ask for the next socket message
      return receiveSocketMessageEffect

    case .receivedSocketMessage(.success):
      // Immediately ask for the next socket message
      return receiveSocketMessageEffect

    case .receivedSocketMessage(.failure):
      return .none

    case .sendButtonTapped:
      let messageToSend = state.messageToSend
      state.messageToSend = ""

      return self.webSocket.send(WebSocketId(), .string(messageToSend))
        .receive(on: self.mainQueue)
        .eraseToEffect()
        .map(Action.sendResponse)

    case let .sendResponse(error):
      if error != nil {
        state.alert = .init(title: .init("Could not send socket message. Try again."))
      }
      return .none

    case .webSocket(.didClose):
      state.connectivityState = .disconnected
      return .cancel(id: WebSocketId())

    case let .webSocket(.didBecomeInvalidWithError(error)),
      let .webSocket(.didCompleteWithError(error)):
      state.connectivityState = .disconnected
      if error != nil {
        state.alert = .init(title: .init("Disconnected from socket for some reason. Try again."))
      }
      return .cancel(id: WebSocketId())

    case .webSocket(.didOpenWithProtocol):
      state.connectivityState = .connected
      return .merge(
        receiveSocketMessageEffect,
        sendPingEffect
      )
    }
  }
}

struct WebSocketView: View {
  let store: StoreOf<WebSocket>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack(alignment: .leading) {
        Text(template: readMe, .body)
          .padding(.bottom)

        HStack {
          TextField(
            "Message to send",
            text: viewStore.binding(
              get: \.messageToSend, send: WebSocket.Action.messageToSendChanged)
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

extension DependencyValues {
  var webSocket: WebSocketClient {
    get { self[WebSocketKey.self] }
    set { self[WebSocketKey.self] = newValue }
  }

  private enum WebSocketKey: LiveDependencyKey {
    static let liveValue = WebSocketClient.live
    static let testValue = WebSocketClient.failing
  }
}

struct WebSocketClient {
  enum Action: Equatable {
    case didBecomeInvalidWithError(NSError?)
    case didClose(code: URLSessionWebSocketTask.CloseCode, reason: Data?)
    case didCompleteWithError(NSError?)
    case didOpenWithProtocol(String?)
  }

  enum Message: Equatable {
    case data(Data)
    case string(String)

    init?(_ message: URLSessionWebSocketTask.Message) {
      switch message {
      case let .data(data):
        self = .data(data)
      case let .string(string):
        self = .string(string)
      @unknown default:
        return nil
      }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case let (.data(lhs), .data(rhs)):
        return lhs == rhs
      case let (.string(lhs), .string(rhs)):
        return lhs == rhs
      case (.data, _), (.string, _):
        return false
      }
    }
  }

  var cancel: (AnyHashable, URLSessionWebSocketTask.CloseCode, Data?) -> Effect<Never, Never>
  var open: (AnyHashable, URL, [String]) -> Effect<Action, Never>
  var receive: (AnyHashable) -> Effect<Message, NSError>
  var send: (AnyHashable, URLSessionWebSocketTask.Message) -> Effect<NSError?, Never>
  var sendPing: (AnyHashable) -> Effect<NSError?, Never>
}

extension WebSocketClient {
  static let live = Self(
    cancel: { id, closeCode, reason in
      .fireAndForget {
        dependencies[id]?.task.cancel(with: closeCode, reason: reason)
        dependencies[id]?.subscriber.send(completion: .finished)
        dependencies[id] = nil
      }
    },
    open: { id, url, protocols in
      Effect.run { subscriber in
        let delegate = WebSocketDelegate(
          didBecomeInvalidWithError: {
            subscriber.send(.didBecomeInvalidWithError($0 as NSError?))
          },
          didClose: {
            subscriber.send(.didClose(code: $0, reason: $1))
          },
          didCompleteWithError: {
            subscriber.send(.didCompleteWithError($0 as NSError?))
          },
          didOpenWithProtocol: {
            subscriber.send(.didOpenWithProtocol($0))
          }
        )
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.webSocketTask(with: url, protocols: protocols)
        task.resume()
        dependencies[id] = Dependencies(delegate: delegate, subscriber: subscriber, task: task)
        return AnyCancellable {
          task.cancel(with: .normalClosure, reason: nil)
          dependencies[id]?.subscriber.send(completion: .finished)
          dependencies[id] = nil
        }
      }
    },
    receive: { id in
      .future { callback in
        dependencies[id]?.task.receive { result in
          switch result.map(Message.init) {
          case let .success(.some(message)):
            callback(.success(message))
          case .success(.none):
            callback(.failure(NSError.init(domain: "co.pointfree", code: 1)))
          case let .failure(error):
            callback(.failure(error as NSError))
          }
        }
      }
    },
    send: { id, message in
      .future { callback in
        dependencies[id]?.task.send(message) { error in
          callback(.success(error as NSError?))
        }
      }
    },
    sendPing: { id in
      .future { callback in
        dependencies[id]?.task.sendPing { error in
          callback(.success(error as NSError?))
        }
      }
    }
  )

  static let failing = Self(
    cancel: { _, _, _ in .failing("\(Self.self).cancel") },
    open: { _, _, _ in .failing("\(Self.self).open") },
    receive: { _ in .failing("\(Self.self).receive") },
    send: { _, _ in .failing("\(Self.self).send") },
    sendPing: { _ in .failing("\(Self.self).sendPing") }
  )
}

private var dependencies: [AnyHashable: Dependencies] = [:]
private struct Dependencies {
  let delegate: URLSessionWebSocketDelegate
  let subscriber: Effect<WebSocketClient.Action, Never>.Subscriber
  let task: URLSessionWebSocketTask
}

private class WebSocketDelegate: NSObject, URLSessionWebSocketDelegate {
  let didBecomeInvalidWithError: (Error?) -> Void
  let didClose: (URLSessionWebSocketTask.CloseCode, Data?) -> Void
  let didCompleteWithError: (Error?) -> Void
  let didOpenWithProtocol: (String?) -> Void

  init(
    didBecomeInvalidWithError: @escaping (Error?) -> Void,
    didClose: @escaping (URLSessionWebSocketTask.CloseCode, Data?) -> Void,
    didCompleteWithError: @escaping (Error?) -> Void,
    didOpenWithProtocol: @escaping (String?) -> Void
  ) {
    self.didBecomeInvalidWithError = didBecomeInvalidWithError
    self.didOpenWithProtocol = didOpenWithProtocol
    self.didCompleteWithError = didCompleteWithError
    self.didClose = didClose
  }

  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
  ) {
    self.didOpenWithProtocol(`protocol`)
  }

  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
    reason: Data?
  ) {
    self.didClose(closeCode, reason)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    self.didCompleteWithError(error)
  }

  func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
    self.didBecomeInvalidWithError(error)
  }
}

// MARK: - SwiftUI previews

struct WebSocketView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      WebSocketView(
        store: Store(
          initialState: .init(receivedMessages: ["Echo"]),
          reducer: WebSocket()
        )
      )
    }
  }
}
