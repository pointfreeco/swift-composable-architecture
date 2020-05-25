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
  var connectivityState = ConnectivityState.disconnected
  var messageToSend = ""
  var receivedMessages = ""

  enum ConnectivityState: String {
    case connected
    case connecting
    case disconnected
  }
}

enum WebSocketAction {
  case connectButtonTapped
  case messageToSendChanged(String)
  case pingResponse(NSError?)
  case receivedSocketMessage(Result<URLSessionWebSocketTask.Message, NSError>)
  case sendButtonTapped
  case sendResponse(NSError?)
  case webSocket(WebSocketClient.Action)
}

struct WebSocketEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var webSocketClient: WebSocketClient
}

let webSocketReducer = Reducer<WebSocketState, WebSocketAction, WebSocketEnvironment> {
  state, action, environment in
  struct WebSocketId: Hashable {}

  switch action {
  case .connectButtonTapped:
    defer { state.connectivityState = .connecting }
    switch state.connectivityState {

    case .connected:
      return environment.webSocketClient.cancel(WebSocketId(), .normalClosure, nil)
        .fireAndForget()
    case .connecting:
      return .none
    case .disconnected:
      return .merge(
        environment.webSocketClient.open(
          WebSocketId(),
          URL(string: "wss://echo.websocket.org")!,
          []
        )
          .receive(on: environment.mainQueue)
          .map(WebSocketAction.webSocket)
          .eraseToEffect(),

        environment.webSocketClient.receive(WebSocketId())
          .receive(on: environment.mainQueue)
          .catchToEffect()
          .map(WebSocketAction.receivedSocketMessage),

        environment.webSocketClient.sendPing(WebSocketId())
          .delay(for: 10, scheduler: environment.mainQueue)
          .map(WebSocketAction.pingResponse)
          .eraseToEffect()
      )
    }

  case let .messageToSendChanged(message):
    state.messageToSend = message
    return .none

  case let .pingResponse(error):
    return environment.webSocketClient.sendPing(WebSocketId())
      .delay(for: 10, scheduler: environment.mainQueue)
      .map(WebSocketAction.pingResponse)
      .eraseToEffect()

  case let .receivedSocketMessage(.success(.string(string))):
    state.receivedMessages += "\(string)\n"
    return environment.webSocketClient.receive(WebSocketId())
      .receive(on: environment.mainQueue)
      .catchToEffect()
      .map(WebSocketAction.receivedSocketMessage)

  case .receivedSocketMessage(.success):
    return environment.webSocketClient.receive(WebSocketId())
      .receive(on: environment.mainQueue)
      .catchToEffect()
      .map(WebSocketAction.receivedSocketMessage)

  case .receivedSocketMessage(.failure):
    return .none

  case .sendButtonTapped:
    let messageToSend = state.messageToSend
    state.messageToSend = ""

    return environment.webSocketClient.send(WebSocketId(), .string(messageToSend))
      .eraseToEffect()
      .map(WebSocketAction.sendResponse)

  case .sendResponse:
    return .none

  case .webSocket(.didOpenWithProtocol):
    state.connectivityState = .connected
    return .none

  case .webSocket(.didClose):
    state.connectivityState = .disconnected
    return .none
  }
}
.debug()

struct WebScoketView: View {
  let store: Store<WebSocketState, WebSocketAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack(alignment: .leading) {
        Text(template: readMe, .body)
          .padding([.bottom])

        HStack {
          TextField(
            "Message to send",
            text: viewStore.binding(get: \.messageToSend, send: WebSocketAction.messageToSendChanged)
          )

          Button(
            viewStore.connectivityState == .connected ? "Disconnect"
              : viewStore.connectivityState == .disconnected ? "Connect"
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
        Text(viewStore.receivedMessages)
      }
      .padding()
      .navigationBarTitle("Web Socket")
    }
  }
}

// MARK: - WebSocketClient

struct WebSocketClient {
  enum Action: Equatable {
    case didOpenWithProtocol(String?)
    case didClose(code: URLSessionWebSocketTask.CloseCode, reason: Data?)
  }

  var open: (AnyHashable, URL, [String]) -> Effect<Action, Never>
  var send: (AnyHashable, URLSessionWebSocketTask.Message) -> Effect<NSError?, Never>
  var sendPing: (AnyHashable) -> Effect<NSError?, Never>
  var receive: (AnyHashable) -> Effect<URLSessionWebSocketTask.Message, NSError>
  var cancel: (AnyHashable, URLSessionWebSocketTask.CloseCode, Data?) -> Effect<Never, Never>
}

extension WebSocketClient {
  static let live = WebSocketClient(
    open: { id, url, protocols in
      Effect.run { subscriber in
        let delegate = WebSocketDelegate(
          didOpenWithProtocol: {
            subscriber.send(.didOpenWithProtocol($0))
        },
          didClose: {
            subscriber.send(.didClose(code: $0, reason: $1))
        })
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.webSocketTask(with: url, protocols: protocols)
        task.resume()
        dependencies[id] = Dependencies(task: task, delegate: delegate)
        return AnyCancellable {
          task.cancel(with: .normalClosure, reason: nil)
          dependencies[id] = nil
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
  },
    receive: { id in
      .future { callback in
        dependencies[id]?.task.receive { result in
          callback(result.mapError { $0 as NSError })
        }
      }
  },
    cancel: { id, closeCode, reason in
      .fireAndForget {
        dependencies[id]?.task.cancel(with: closeCode, reason: reason)
        dependencies[id] = nil
      }
  })
}

private var dependencies: [AnyHashable: Dependencies] = [:]
private struct Dependencies {
  let task: URLSessionWebSocketTask
  let delegate: URLSessionWebSocketDelegate
}

class WebSocketDelegate: NSObject, URLSessionWebSocketDelegate {
  let didOpenWithProtocol: (String?) -> Void
  let didClose: (URLSessionWebSocketTask.CloseCode, Data?) -> Void

  init(
    didOpenWithProtocol: @escaping (String?) -> Void,
    didClose: @escaping (URLSessionWebSocketTask.CloseCode, Data?) -> Void
  ) {
    self.didOpenWithProtocol = didOpenWithProtocol
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
}

// MARK: - SwiftUI previews

struct WebSocketView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      WebScoketView(
        store: Store(
          initialState: .init(receivedMessages: "Echo"),
          reducer: webSocketReducer,
          environment: WebSocketEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
            webSocketClient: .live
          )
        )
      )
    }
  }
}
