import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class WebSocketTests: XCTestCase {
  func testWebSocketHappyPath() async {
    let actions = AsyncStream.makeStream(of: WebSocketClient.Action.self)
    let messages = AsyncStream.makeStream(of: TaskResult<WebSocketClient.Message>.self)

    let store = TestStore(initialState: WebSocket.State()) {
      WebSocket()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.webSocket.open = { _, _, _ in actions.stream }
      $0.webSocket.receive = { _ in messages.stream }
      $0.webSocket.send = { _, _ in }
      $0.webSocket.sendPing = { _ in try await Task.never() }
    }

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
    let actions = AsyncStream.makeStream(of: WebSocketClient.Action.self)
    let messages = AsyncStream.makeStream(of: TaskResult<WebSocketClient.Message>.self)

    let store = TestStore(initialState: WebSocket.State()) {
      WebSocket()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.webSocket.open = { _, _, _ in actions.stream }
      $0.webSocket.receive = { _ in messages.stream }
      $0.webSocket.send = { _, _ in
        struct SendFailure: Error, Equatable {}
        throw SendFailure()
      }
      $0.webSocket.sendPing = { _ in try await Task.never() }
    }

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
    let actions = AsyncStream.makeStream(of: WebSocketClient.Action.self)
    let clock = TestClock()
    var pingsCount = 0

    let store = TestStore(initialState: WebSocket.State()) {
      WebSocket()
    } withDependencies: {
      $0.continuousClock = clock
      $0.webSocket.open = { _, _, _ in actions.stream }
      $0.webSocket.receive = { _ in try await Task.never() }
      $0.webSocket.sendPing = { @MainActor _ in pingsCount += 1 }
    }

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
    let actions = AsyncStream.makeStream(of: WebSocketClient.Action.self)

    let store = TestStore(initialState: WebSocket.State()) {
      WebSocket()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.webSocket.open = { _, _, _ in actions.stream }
      $0.webSocket.receive = { _ in try await Task.never() }
      $0.webSocket.sendPing = { _ in try await Task.never() }
    }

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
