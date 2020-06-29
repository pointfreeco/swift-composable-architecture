import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class WebSocketTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testWebSocketHappyPath() {
    let socketSubject = PassthroughSubject<WebSocketClient.Action, Never>()
    let receiveSubject = PassthroughSubject<WebSocketClient.Message, NSError>()

    let testStore = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        webSocket: .mock(
          open: { _, _, _ in socketSubject.eraseToEffect() },
          receive: { _ in receiveSubject.eraseToEffect() },
          send: { _, _ in Effect(value: nil) },
          sendPing: { _ in .none }
        )
      )
    )

    testStore.assert(
      // Connect to the socket
      .send(.connectButtonTapped) {
        $0.connectivityState = .connecting
      },
      .do { socketSubject.send(.didOpenWithProtocol(nil)) },
      .do { self.scheduler.advance() },
      .receive(.webSocket(.didOpenWithProtocol(nil))) {
        $0.connectivityState = .connected
      },

      // Send a message
      .send(.messageToSendChanged("Hi")) {
        $0.messageToSend = "Hi"
      },
      .send(.sendButtonTapped) {
        $0.messageToSend = ""
      },
      .receive(.sendResponse(nil)),

      // Receive a message
      .do { receiveSubject.send(.string("Hi")) },
      .do { self.scheduler.advance() },
      .receive(.receivedSocketMessage(.success(.string("Hi")))) {
        $0.receivedMessages = ["Hi"]
      },

      // Disconnect from the socket
      .send(.connectButtonTapped) {
        $0.connectivityState = .disconnected
      }
    )
  }

  func testWebSocketSendFailure() {
    let socketSubject = PassthroughSubject<WebSocketClient.Action, Never>()
    let receiveSubject = PassthroughSubject<WebSocketClient.Message, NSError>()

    let testStore = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        webSocket: .mock(
          open: { _, _, _ in socketSubject.eraseToEffect() },
          receive: { _ in receiveSubject.eraseToEffect() },
          send: { _, _ in Effect(value: NSError(domain: "", code: 1)) },
          sendPing: { _ in .none }
        )
      )
    )

    testStore.assert(
      // Connect to the socket
      .send(.connectButtonTapped) {
        $0.connectivityState = .connecting
      },
      .do { socketSubject.send(.didOpenWithProtocol(nil)) },
      .do { self.scheduler.advance() },
      .receive(.webSocket(.didOpenWithProtocol(nil))) {
        $0.connectivityState = .connected
      },

      // Send a message
      .send(.messageToSendChanged("Hi")) {
        $0.messageToSend = "Hi"
      },
      .send(.sendButtonTapped) {
        $0.messageToSend = ""
      },
      .receive(.sendResponse(NSError(domain: "", code: 1))) {
        $0.alert = .init(title: "Could not send socket message. Try again.")
      },

      // Disconnect from the socket
      .send(.connectButtonTapped) {
        $0.connectivityState = .disconnected
      }
    )
  }

  func testWebSocketPings() {
    let socketSubject = PassthroughSubject<WebSocketClient.Action, Never>()
    let pingSubject = PassthroughSubject<NSError?, Never>()

    let testStore = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        webSocket: .mock(
          open: { _, _, _ in socketSubject.eraseToEffect() },
          receive: { _ in .none },
          sendPing: { _ in pingSubject.eraseToEffect() }
        )
      )
    )

    testStore.assert(
      .send(.connectButtonTapped) {
        $0.connectivityState = .connecting
      },

      .do { socketSubject.send(.didOpenWithProtocol(nil)) },
      .do { self.scheduler.advance() },
      .receive(.webSocket(.didOpenWithProtocol(nil))) {
        $0.connectivityState = .connected
      },

      .do { pingSubject.send(nil) },
      .do { self.scheduler.advance(by: .seconds(5)) },
      .do { self.scheduler.advance(by: .seconds(5)) },
      .receive(.pingResponse(nil)),

      .send(.connectButtonTapped) {
        $0.connectivityState = .disconnected
      }
    )
  }

  func testWebSocketConnectError() {
    let socketSubject = PassthroughSubject<WebSocketClient.Action, Never>()

    let testStore = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        webSocket: .mock(
          cancel: { _, _, _ in .fireAndForget { socketSubject.send(completion: .finished) } },
          open: { _, _, _ in socketSubject.eraseToEffect() },
          receive: { _ in .none },
          sendPing: { _ in .none }
        )
      )
    )

    testStore.assert(
      .send(.connectButtonTapped) {
        $0.connectivityState = .connecting
      },

      .do { socketSubject.send(.didClose(code: .internalServerError, reason: nil)) },
      .do { self.scheduler.advance() },
      .receive(.webSocket(.didClose(code: .internalServerError, reason: nil))) {
        $0.connectivityState = .disconnected
      }
    )
  }
}

extension WebSocketClient {
  static func mock(
    cancel: @escaping (AnyHashable, URLSessionWebSocketTask.CloseCode, Data?) -> Effect<
      Never, Never
    > = { _, _, _ in fatalError() },
    open: @escaping (AnyHashable, URL, [String]) -> Effect<Action, Never> = { _, _, _ in
      fatalError()
    },
    receive: @escaping (AnyHashable) -> Effect<Message, NSError> = { _ in fatalError() },
    send: @escaping (AnyHashable, URLSessionWebSocketTask.Message) -> Effect<NSError?, Never> = {
      _, _ in fatalError()
    },
    sendPing: @escaping (AnyHashable) -> Effect<NSError?, Never> = { _in in fatalError() }
  ) -> Self {
    Self(
      cancel: cancel,
      open: open,
      receive: receive,
      send: send,
      sendPing: sendPing
    )
  }
}
