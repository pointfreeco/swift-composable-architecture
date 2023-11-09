import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

@MainActor
final class EffectDelayTests: BaseTCATestCase {
  func testDeprecatedDelay() async {
    let mainQueue = DispatchQueue.test
    var currentValue: Int?

    @discardableResult
    func runDelayedEffect(value: Int) -> Task<Void, Never> {
      Task {
        struct CancelToken: Hashable {}

        let effect = Effect.send(value)
          .delay(id: CancelToken(), for: 1, scheduler: mainQueue)

        for await action in effect.actions {
          currentValue = action
        }
      }
    }

    runDelayedEffect(value: 1)
    await mainQueue.advance()
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // Waiting for the delayed time
    await mainQueue.advance(by: .seconds(1))
    XCTAssertEqual(currentValue, 1)
  }

  func testDeprecatedDelayMultiple() async {
    let mainQueue = DispatchQueue.test
    var currentValue: Int?

    @discardableResult
    func runDelayedEffect(value: Int) -> Task<Void, Never> {
      Task {
        struct CancelToken: Hashable {}

        let effect = Effect.send(value)
          .delay(id: CancelToken(), for: 1, scheduler: mainQueue)

        for await action in effect.actions {
          currentValue = action
        }
      }
    }

    runDelayedEffect(value: 1)
    await mainQueue.advance()
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // 0.5 s
    await mainQueue.advance(by: .seconds(0.5))
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    runDelayedEffect(value: 2)
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // 1.0 s
    // Waiting for the second value.
    await mainQueue.advance(by: .seconds(0.5))
    XCTAssertEqual(currentValue, 1)

    runDelayedEffect(value: 3)

    // 1.5 s
    // Waiting for the second value.
    await mainQueue.advance(by: .seconds(0.5))
    XCTAssertEqual(currentValue, 2)

    // 2.0 s
    // Waiting for the third value.
    await mainQueue.advance(by: .seconds(0.5))
    XCTAssertEqual(currentValue, 3)
  }

  func testDeprecatedDelayCanceledInFlight() async {
    let mainQueue = DispatchQueue.test
    var currentValue: Int?

    @discardableResult
    func runDelayedEffect(value: Int) -> Task<Void, Never> {
      Task {
        struct CancelToken: Hashable {}

        let effect = Effect.send(value)
          .delay(id: CancelToken(), for: 1, scheduler: mainQueue, cancelInFlight: true)

        for await action in effect.actions {
          currentValue = action
        }
      }
    }

    runDelayedEffect(value: 1)
    await mainQueue.advance()
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // 0.5 s
    await mainQueue.advance(by: .seconds(0.5))
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    runDelayedEffect(value: 2)
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // 1.0 s
    // Waiting for the second value
    await mainQueue.advance(by: .seconds(0.5))
    // Nothing emits right away because the previos call was canceled
    XCTAssertNil(currentValue)

    runDelayedEffect(value: 3)

    // 1.5 s
    // Waiting for the second value
    await mainQueue.advance(by: .seconds(0.5))
    // Nothing emits right away because the previos call was canceled
    XCTAssertNil(currentValue)

    // 2.0 s
    // Waiting for the third value
    await mainQueue.advance(by: .seconds(0.5))
    // Checking the last call
    XCTAssertEqual(currentValue, 3)
  }

  @available(iOS 16, *)
  func testDelay() async {
    let clock = TestClock()
    var currentValue: Int?

    @discardableResult
    func runDelayedEffect(value: Int) -> Task<Void, Never> {
      Task {
        struct CancelToken: Hashable {}

        let effect = Effect.send(value)
          .delay(id: CancelToken(), for: .seconds(1), clock: clock)

        for await action in effect.actions {
          currentValue = action
        }
      }
    }

    runDelayedEffect(value: 1)
    await clock.advance()
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // Waiting for the delayed time
    await clock.advance(by: .seconds(1))
    XCTAssertEqual(currentValue, 1)
  }

  @available(iOS 16, *)
  func testDelayMultiple() async {
    let clock = TestClock()
    var currentValue: Int?

    @discardableResult
    func runDelayedEffect(value: Int) -> Task<Void, Never> {
      Task {
        struct CancelToken: Hashable {}

        let effect = Effect.send(value)
          .delay(id: CancelToken(), for: .seconds(1), clock: clock)

        for await action in effect.actions {
          currentValue = action
        }
      }
    }

    runDelayedEffect(value: 1)
    await clock.advance()
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // 0.5 s
    await clock.advance(by: .seconds(0.5))
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    runDelayedEffect(value: 2)
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // 1.0 s
    // Waiting for the second value.
    await clock.advance(by: .seconds(0.5))
    XCTAssertEqual(currentValue, 1)

    runDelayedEffect(value: 3)

    // 1.5 s
    // Waiting for the second value.
    await clock.advance(by: .seconds(0.5))
    XCTAssertEqual(currentValue, 2)

    // 2.0 s
    // Waiting for the third value.
    await clock.advance(by: .seconds(0.5))
    XCTAssertEqual(currentValue, 3)
  }

  @available(iOS 16, *)
  func testDelayCanceledInFlight() async {
    let clock = TestClock()
    var currentValue: Int?

    @discardableResult
    func runDelayedEffect(value: Int) -> Task<Void, Never> {
      Task {
        struct CancelToken: Hashable {}

        let effect = Effect.send(value)
          .delay(id: CancelToken(), for: .seconds(1), clock: clock, cancelInFlight: true)

        for await action in effect.actions {
          currentValue = action
        }
      }
    }

    runDelayedEffect(value: 1)
    await clock.advance()
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // 0.5 s
    await clock.advance(by: .seconds(0.5))
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    runDelayedEffect(value: 2)
    // Nothing emits right away.
    XCTAssertNil(currentValue)

    // 1.0 s
    await clock.advance(by: .seconds(0.5))
    // Nothing emits right away because the previos call was canceled
    XCTAssertNil(currentValue)

    runDelayedEffect(value: 3)

    // 1.5 s
    await clock.advance(by: .seconds(0.5))
    // Nothing emits right away because the previos call was canceled
    XCTAssertNil(currentValue)

    // 2.0 s
    // Waiting for the third value
    await clock.advance(by: .seconds(0.5))
    // Checking the last call
    XCTAssertEqual(currentValue, 3)
  }
}
