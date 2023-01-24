import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class WebSocketTests: XCTestCase {
  func testWebSocketHappyPath() async {
    let store = TestStore(
      initialState: WebSocket.State(),
      reducer: WebSocket()
    )

    let actions = AsyncStream<WebSocketClient.Action>.streamWithContinuation()
    let messages = AsyncStream<TaskResult<WebSocketClient.Message>>.streamWithContinuation()

    store.dependencies.continuousClock = ImmediateClock()
    store.dependencies.webSocket.open = { _, _, _ in actions.stream }
    store.dependencies.webSocket.receive = { _ in messages.stream }
    store.dependencies.webSocket.send = { _, _ in }
    store.dependencies.webSocket.sendPing = { _ in try await Task.never() }

    // Connect to the socket
    await store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    actions.continuation.yield(.didOpen(protocol: nil))
    await store.receive(.webSocket(.didOpen(protocol: nil))) {
      $0.connectivityState = .connected
    }

    // Receive a message
    messages.continuation.yield(.success(.string("Welcome to echo.pointfree.co")))
    await store.receive(.receivedSocketMessage(.success(.string("Welcome to echo.pointfree.co")))) {
      $0.receivedMessages = ["Welcome to echo.pointfree.co"]
    }

    // Send a message
    await store.send(.messageToSendChanged("Hi")) {
      $0.messageToSend = "Hi"
    }
    await store.send(.sendButtonTapped) {
      $0.messageToSend = ""
    }
    await store.receive(.sendResponse(didSucceed: true))

    // Receive a message
    messages.continuation.yield(.success(.string("Hi")))
    await store.receive(.receivedSocketMessage(.success(.string("Hi")))) {
      $0.receivedMessages = ["Welcome to echo.pointfree.co", "Hi"]
    }

    // Disconnect from the socket
    await store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
    await store.finish()
  }

  func testWebSocketSendFailure() async {
    let store = TestStore(
      initialState: WebSocket.State(),
      reducer: WebSocket()
    )

    let actions = AsyncStream<WebSocketClient.Action>.streamWithContinuation()
    let messages = AsyncStream<TaskResult<WebSocketClient.Message>>.streamWithContinuation()

    store.dependencies.continuousClock = ImmediateClock()
    store.dependencies.webSocket.open = { _, _, _ in actions.stream }
    store.dependencies.webSocket.receive = { _ in messages.stream }
    store.dependencies.webSocket.send = { _, _ in
      struct SendFailure: Error, Equatable {}
      throw SendFailure()
    }
    store.dependencies.webSocket.sendPing = { _ in try await Task.never() }

    // Connect to the socket
    await store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    actions.continuation.yield(.didOpen(protocol: nil))
    await store.receive(.webSocket(.didOpen(protocol: nil))) {
      $0.connectivityState = .connected
    }

    // Send a message
    await store.send(.messageToSendChanged("Hi")) {
      $0.messageToSend = "Hi"
    }
    await store.send(.sendButtonTapped) {
      $0.messageToSend = ""
    }
    await store.receive(.sendResponse(didSucceed: false)) {
      $0.alert = AlertState {
        TextState("Could not send socket message. Connect to the server first, and try again.")
      }
    }

    // Disconnect from the socket
    await store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
    await store.finish()
  }

  func testWebSocketPings() async {
    let store = TestStore(
      initialState: WebSocket.State(),
      reducer: WebSocket()
    )

    let actions = AsyncStream<WebSocketClient.Action>.streamWithContinuation()
    let clock = TestClock()
    var pingsCount = 0

    store.dependencies.continuousClock = clock
    store.dependencies.webSocket.open = { _, _, _ in actions.stream }
    store.dependencies.webSocket.receive = { _ in try await Task.never() }
    store.dependencies.webSocket.sendPing = { @MainActor _ in pingsCount += 1 }

    // Connect to the socket
    await store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    actions.continuation.yield(.didOpen(protocol: nil))
    await store.receive(.webSocket(.didOpen(protocol: nil))) {
      $0.connectivityState = .connected
    }

    // Wait for ping
    XCTAssertEqual(pingsCount, 0)
    await clock.advance(by: .seconds(10))
    XCTAssertEqual(pingsCount, 1)

    // Disconnect from the socket
    await store.send(.connectButtonTapped) {
      $0.connectivityState = .disconnected
    }
  }

  func testWebSocketConnectError() async {
    let store = TestStore(
      initialState: WebSocket.State(),
      reducer: WebSocket()
    )

    let actions = AsyncStream<WebSocketClient.Action>.streamWithContinuation()

    store.dependencies.continuousClock = ImmediateClock()
    store.dependencies.webSocket.open = { _, _, _ in actions.stream }
    store.dependencies.webSocket.receive = { _ in try await Task.never() }
    store.dependencies.webSocket.sendPing = { _ in try await Task.never() }

    // Attempt to connect to the socket
    await store.send(.connectButtonTapped) {
      $0.connectivityState = .connecting
    }
    actions.continuation.yield(.didClose(code: .internalServerError, reason: nil))
    await store.receive(.webSocket(.didClose(code: .internalServerError, reason: nil))) {
      $0.connectivityState = .disconnected
    }
  }
}
