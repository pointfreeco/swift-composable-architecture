import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class WebSocketTests: XCTestCase {
  func testWebSocketHappyPath() async {
    let actions = AsyncStream<WebSocketClient.Action>.pipe()
    let messages = AsyncStream<WebSocketClient.Message>.pipe()

    var webSocket = WebSocketClient.failing
    webSocket.open = { _, _, _ in actions.stream }
    webSocket.send = { _, _ in }
    webSocket.receive = { _ in try await messages.stream.always }
    webSocket.sendPing = { _ in try await Task.never() }

    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: .immediate,
        webSocket: webSocket
      )
    )

    // Connect to the socket
    let task = store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    actions.continuation.yield(.didOpen(protocol: nil))
    await store.receive(.webSocket(.didOpen(protocol: nil))) {
      $0.connectivityState = .connected
    }

    // Receive a message
    messages.continuation.yield(.string("Welcome to echo.pointfree.co"))
    await store.receive(.receivedSocketMessage(.success(.string("Welcome to echo.pointfree.co")))) {
      $0.receivedMessages = ["Welcome to echo.pointfree.co"]
    }

    // Send a message
    store.send(.messageToSendChanged("Hi")) {
      $0.messageToSend = "Hi"
    }
    store.send(.sendButtonTapped) {
      $0.messageToSend = ""
    }
    await store.receive(.sendResponse(.success(.init())))

    // Receive a message
    messages.continuation.yield(.string("Hi"))
    await store.receive(.receivedSocketMessage(.success(.string("Hi")))) {
      $0.receivedMessages = ["Welcome to echo.pointfree.co", "Hi"]
    }

    // Disconnect from the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
    await task.value
  }

  func testWebSocketSendFailure() async {
    let actions = AsyncStream<WebSocketClient.Action>.pipe()
    let messages = AsyncStream<WebSocketClient.Message>.pipe()

    var webSocket = WebSocketClient.failing
    webSocket.open = { _, _, _ in actions.stream }
    webSocket.receive = { _ in try await messages.stream.always }
    struct SendFailure: Error, Equatable {}
    webSocket.send = { _, _ in throw SendFailure() }
    webSocket.sendPing = { _ in try await Task.never() }

    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: .immediate,
        webSocket: webSocket
      )
    )

    // Connect to the socket
    let task = store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    actions.continuation.yield(.didOpen(protocol: nil))
    await store.receive(.webSocket(.didOpen(protocol: nil))) {
      $0.connectivityState = .connected
    }

    // Send a message
    store.send(.messageToSendChanged("Hi")) {
      $0.messageToSend = "Hi"
    }
    store.send(.sendButtonTapped) {
      $0.messageToSend = ""
    }
    await store.receive(.sendResponse(.failure(SendFailure()))) {
      $0.alert = .init(title: .init("Could not send socket message. Try again."))
    }

    // Disconnect from the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
    await task.value
  }

  func testWebSocketPings() async {
    let actions = AsyncStream<WebSocketClient.Action>.pipe()
    let pingsCount = SendableState(0)

    var webSocket = WebSocketClient.failing
    webSocket.open = { _, _, _ in actions.stream }
    webSocket.receive = { _ in try await Task.never() }
    webSocket.sendPing = { _ in await pingsCount.modify { $0 += 1 } }

    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        webSocket: webSocket
      )
    )

    // Connect to the socket
    let task = store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    actions.continuation.yield(.didOpen(protocol: nil))
    await store.receive(.webSocket(.didOpen(protocol: nil))) {
      $0.connectivityState = .connected
    }

    // Wait for ping
    let before = await pingsCount.value
    XCTAssertEqual(before, 0)
    await scheduler.advance(by: .seconds(10))
    let after = await pingsCount.value
    XCTAssertEqual(after, 1)

    // Disconnect from the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
    await task.value
  }

  func testWebSocketConnectError() async {
    let actions = AsyncStream<WebSocketClient.Action>.pipe()

    var webSocket = WebSocketClient.failing
    webSocket.open = { _, _, _ in actions.stream }
    webSocket.receive = { _ in try await Task.never() }
    webSocket.sendPing = { _ in try await Task.never() }

    let store = TestStore(
      initialState: .init(),
      reducer: webSocketReducer,
      environment: WebSocketEnvironment(
        mainQueue: .immediate,
        webSocket: webSocket
      )
    )

    // Attempt to connect to the socket
    store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    actions.continuation.yield(.didClose(code: .internalServerError, reason: nil))
    await store.receive(.webSocket(.didClose(code: .internalServerError, reason: nil))) {
      $0.connectivityState = .disconnected
    }
  }
}
