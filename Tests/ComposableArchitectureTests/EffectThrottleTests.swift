import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class EffectThrottleTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []
  let mainQueue = DispatchQueue.test

  func testThrottleLatest() async {
    var values: [Int] = []
    var effectRuns = 0

    // NB: Explicit @MainActor is needed for Swift 5.5.2
    @MainActor func runThrottledEffect(value: Int) {
      enum CancelToken {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .throttle(
        id: CancelToken.self, for: 1, scheduler: mainQueue.eraseToAnyScheduler(), latest: true
      )
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runThrottledEffect(value: 1)

    await mainQueue.advance()

    // A value emits right away.
    XCTAssertEqual(values, [1])

    runThrottledEffect(value: 2)

    await mainQueue.advance()

    // A second value is throttled.
    XCTAssertEqual(values, [1])

    await mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 3)

    await mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 4)

    await mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 5)

    // A third value is throttled.
    XCTAssertEqual(values, [1])

    await mainQueue.advance(by: 0.25)

    // The latest value emits.
    XCTAssertEqual(values, [1, 5])
  }

  func testThrottleFirst() async {
    var values: [Int] = []
    var effectRuns = 0

    // NB: Explicit @MainActor is needed for Swift 5.5.2
    @MainActor func runThrottledEffect(value: Int) {
      enum CancelToken {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .throttle(
        id: CancelToken.self, for: 1, scheduler: mainQueue.eraseToAnyScheduler(), latest: false
      )
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runThrottledEffect(value: 1)

    await mainQueue.advance()

    // A value emits right away.
    XCTAssertEqual(values, [1])

    runThrottledEffect(value: 2)

    await mainQueue.advance()

    // A second value is throttled.
    XCTAssertEqual(values, [1])

    await mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 3)

    await mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 4)

    await mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 5)

    await mainQueue.advance(by: 0.25)

    // The second (throttled) value emits.
    XCTAssertEqual(values, [1, 2])

    await mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 6)

    await mainQueue.advance(by: 0.50)

    // A third value is throttled.
    XCTAssertEqual(values, [1, 2])

    runThrottledEffect(value: 7)

    await mainQueue.advance(by: 0.25)

    // The third (throttled) value emits.
    XCTAssertEqual(values, [1, 2, 6])
  }

  func testThrottleAfterInterval() async {
    var values: [Int] = []
    var effectRuns = 0

    // NB: Explicit @MainActor is needed for Swift 5.5.2
    @MainActor func runThrottledEffect(value: Int) {
      enum CancelToken {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .throttle(
        id: CancelToken.self, for: 1, scheduler: mainQueue.eraseToAnyScheduler(), latest: true
      )
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runThrottledEffect(value: 1)

    await mainQueue.advance()

    // A value emits right away.
    XCTAssertEqual(values, [1])

    await mainQueue.advance(by: 2)

    runThrottledEffect(value: 2)

    await mainQueue.advance()

    // A second value is emitted right away.
    XCTAssertEqual(values, [1, 2])

    await mainQueue.advance(by: 2)

    runThrottledEffect(value: 3)

    await mainQueue.advance()

    // A third value is emitted right away.
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testThrottleEmitsFirstValueOnce() async {
    var values: [Int] = []
    var effectRuns = 0

    // NB: Explicit @MainActor is needed for Swift 5.5.2
    @MainActor func runThrottledEffect(value: Int) {
      enum CancelToken {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .throttle(
        id: CancelToken.self, for: 1, scheduler: mainQueue.eraseToAnyScheduler(), latest: false
      )
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runThrottledEffect(value: 1)

    await mainQueue.advance()

    // A value emits right away.
    XCTAssertEqual(values, [1])

    await mainQueue.advance(by: 0.5)

    runThrottledEffect(value: 2)

    await mainQueue.advance(by: 0.5)

    runThrottledEffect(value: 3)

    // A second value is emitted right away.
    XCTAssertEqual(values, [1, 2])
  }
}
