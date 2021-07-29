import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class WebSocketTests: XCTestCase {
  func testWebSocketHappyPath() {
    let socketSubject = PassthroughSubject<WebSocketClient.Action, Never>()
    let receiveSubject = PassthroughSubject<WebSocketClient.Message, NSError>()

    var webSocket = WebSocketClient.failing
    webSocket.open = { _, _, _ in socketSubject.eraseToEffect() }
    webSocket.receive = { _ in receiveSubject.eraseToEffect() }
    webSocket.send = { _, _ in Effect(value: nil) }
    webSocket.sendPing = { _ in .none }

    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: .immediate,
        webSocket: webSocket
      )
    )

    // Connect to the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    socketSubject.send(.didOpenWithProtocol(nil))
    store.receive(.webSocket(.didOpenWithProtocol(nil))) {
      $0.connectivityState = .connected
    }

    // Send a message
    store.send(.messageToSendChanged("Hi")) {
      $0.messageToSend = "Hi"
    }
    store.send(.sendButtonTapped) {
      $0.messageToSend = ""
    }
    store.receive(.sendResponse(nil))

    // Receive a message
    receiveSubject.send(.string("Hi"))
    store.receive(.receivedSocketMessage(.success(.string("Hi")))) {
      $0.receivedMessages = ["Hi"]
    }

    // Disconnect from the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
  }

  func testWebSocketSendFailure() {
    let socketSubject = PassthroughSubject<WebSocketClient.Action, Never>()
    let receiveSubject = PassthroughSubject<WebSocketClient.Message, NSError>()

    var webSocket = WebSocketClient.failing
    webSocket.open = { _, _, _ in socketSubject.eraseToEffect() }
    webSocket.receive = { _ in receiveSubject.eraseToEffect() }
    webSocket.send = { _, _ in Effect(value: NSError(domain: "", code: 1)) }
    webSocket.sendPing = { _ in .none }

    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: .immediate,
        webSocket: webSocket
      )
    )

    // Connect to the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    socketSubject.send(.didOpenWithProtocol(nil))
    store.receive(.webSocket(.didOpenWithProtocol(nil))) {
      $0.connectivityState = .connected
    }

    // Send a message
    store.send(.messageToSendChanged("Hi")) {
      $0.messageToSend = "Hi"
    }
    store.send(.sendButtonTapped) {
      $0.messageToSend = ""
    }
    store.receive(.sendResponse(NSError(domain: "", code: 1))) {
      $0.alert = .init(title: .init("Could not send socket message. Try again."))
    }

    // Disconnect from the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
  }

  func testWebSocketPings() {
    let socketSubject = PassthroughSubject<WebSocketClient.Action, Never>()
    let pingSubject = PassthroughSubject<NSError?, Never>()

    var webSocket = WebSocketClient.failing
    webSocket.open = { _, _, _ in socketSubject.eraseToEffect() }
    webSocket.receive = { _ in .none }
    webSocket.sendPing = { _ in pingSubject.eraseToEffect() }

    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        webSocket: webSocket
      )
    )

    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }

    socketSubject.send(.didOpenWithProtocol(nil))
    scheduler.advance()
    store.receive(.webSocket(.didOpenWithProtocol(nil))) {
      $0.connectivityState = .connected
    }

    pingSubject.send(nil)
    scheduler.advance(by: .seconds(5))
    scheduler.advance(by: .seconds(5))
    store.receive(.pingResponse(nil))

    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
  }

  func testWebSocketConnectError() {
    let socketSubject = PassthroughSubject<WebSocketClient.Action, Never>()

    var webSocket = WebSocketClient.failing
    webSocket.cancel = { _, _, _ in .fireAndForget { socketSubject.send(completion: .finished) } }
    webSocket.open = { _, _, _ in socketSubject.eraseToEffect() }
    webSocket.receive = { _ in .none }
    webSocket.sendPing = { _ in .none }

    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: .immediate,
        webSocket: webSocket
      )
    )

    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }

    socketSubject.send(.didClose(code: .internalServerError, reason: nil))
    store.receive(.webSocket(.didClose(code: .internalServerError, reason: nil))) {
      $0.connectivityState = .disconnected
    }
  }
}

extension WebSocketClient {
  static let failing = Self(
    cancel: { _, _, _ in .failing("WebSocketClient.cancel") },
    open: { _, _, _ in .failing("WebSocketClient.open") },
    receive: { _ in .failing("WebSocketClient.receive") },
    send: { _, _ in .failing("WebSocketClient.send") },
    sendPing: { _ in .failing("WebSocketClient.sendPing") }
  )
}
