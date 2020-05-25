import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  """

private var dependencies: [AnyHashable: Dependencies] = [:]
private struct Dependencies {
  let task: URLSessionWebSocketTask
  let delegate: URLSessionWebSocketDelegate?
}

struct WebSocketState: Equatable {
  var messageToSend = ""
  var receivedMessages = ""
}

enum WebSocketAction {
  case messageToSendChanged(String)
  case onAppear
  case receivedSocketMessage(Result<URLSessionWebSocketTask.Message, NSError>)
  case sendButtonTapped
  case sendResponse(NSError?)
  case webSocket(WebSocketClient.Action)
}

struct WebSocketEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var webSocketClient: WebSocketClient
}

// fireAndForget: Effect<A, E> -> Effect<B, Never>

extension Effect {
  func _fireAndForget<B>() -> Effect<B, Never> {
    self
      .flatMap { _ in Empty(completeImmediately: true) }
      .replaceError(with: B?.none)
      .compactMap { $0 }
      .eraseToEffect()
  }
}

let webSocketReducer = Reducer<WebSocketState, WebSocketAction, WebSocketEnvironment> {
  state, action, environment in
  struct WebSocketId: Hashable {}

  switch action {
  case let .messageToSendChanged(message):
    state.messageToSend = message
    return .none

  case .onAppear:
    return .merge(
      environment.webSocketClient.open(WebSocketId(), URL(string: "wss://echo.websocket.org")!, [])
        .map(WebSocketAction.webSocket),

      environment.webSocketClient.receive(WebSocketId())
        .receive(on: environment.mainQueue)
        .catchToEffect()
        .map(WebSocketAction.receivedSocketMessage)

//      Effect.timer(id: "PingCancelId()", every: 10, on: environment.mainQueue)
//        .flatMap { _ in environment.webSocketClient.sendPing(WebSocketId()) }
//        .catchToEffect()
//        ._fireAndForget()
    )

  case let .receivedSocketMessage(.success(.data(data))):
    return environment.webSocketClient.receive(WebSocketId())
      .receive(on: environment.mainQueue)
      .catchToEffect()
      .map(WebSocketAction.receivedSocketMessage)

  case let .receivedSocketMessage(.success(.string(string))):
    state.receivedMessages += "\(string)\n\n"
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
    return .none
  case .webSocket(.didClose):
    return .none

  }
}
.debug()

struct WebScoketView: View {
  let store: Store<WebSocketState, WebSocketAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        Text(template: readMe, .body)

        TextField("Message to send", text: viewStore.binding(get: \.messageToSend, send: WebSocketAction.messageToSendChanged))

        Button.init("Send message", action: { viewStore.send(.sendButtonTapped)} )

        Text(viewStore.receivedMessages)
      }
      .padding()
      .navigationBarTitle("Web Socket")
      .onAppear { viewStore.send(.onAppear) }
    }
  }
}

// MARK: - WebSocketClient

struct WebSocketClient {
  struct Success: Equatable {}

  enum Action: Equatable {
    case didOpenWithProtocol(String?)
    case didClose(URLSessionWebSocketTask.CloseCode)
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
        let task = URLSession.shared.webSocketTask(with: url, protocols: protocols)
        task.resume()
        dependencies[id] = Dependencies(task: task, delegate: nil)
        return AnyCancellable {
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

// MARK: - SwiftUI previews

struct WebSocketView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      WebScoketView(
        store: Store(
          initialState: .init(),
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
