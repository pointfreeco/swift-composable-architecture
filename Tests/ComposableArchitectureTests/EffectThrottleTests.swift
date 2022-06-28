import Combine
import XCTest

@testable import ComposableArchitecture

final class EffectThrottleTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []
  let mainQueue = DispatchQueue.test

  func testThrottleLatest() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
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

    mainQueue.advance()

    // A value emits right away.
    XCTAssertNoDifference(values, [1])

    runThrottledEffect(value: 2)

    mainQueue.advance()

    // A second value is throttled.
    XCTAssertNoDifference(values, [1])

    mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 3)

    mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 4)

    mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 5)

    // A third value is throttled.
    XCTAssertNoDifference(values, [1])

    mainQueue.advance(by: 0.25)

    // The latest value emits.
    XCTAssertNoDifference(values, [1, 5])
  }

  func testThrottleFirst() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
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

    mainQueue.advance()

    // A value emits right away.
    XCTAssertNoDifference(values, [1])

    runThrottledEffect(value: 2)

    mainQueue.advance()

    // A second value is throttled.
    XCTAssertNoDifference(values, [1])

    mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 3)

    mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 4)

    mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 5)

    mainQueue.advance(by: 0.25)

    // The second (throttled) value emits.
    XCTAssertNoDifference(values, [1, 2])

    mainQueue.advance(by: 0.25)

    runThrottledEffect(value: 6)

    mainQueue.advance(by: 0.50)

    // A third value is throttled.
    XCTAssertNoDifference(values, [1, 2])

    runThrottledEffect(value: 7)

    mainQueue.advance(by: 0.25)

    // The third (throttled) value emits.
    XCTAssertNoDifference(values, [1, 2, 6])
  }

  func testThrottleAfterInterval() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
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

    mainQueue.advance()

    // A value emits right away.
    XCTAssertNoDifference(values, [1])

    mainQueue.advance(by: 2)

    runThrottledEffect(value: 2)

    mainQueue.advance()

    // A second value is emitted right away.
    XCTAssertNoDifference(values, [1, 2])

    mainQueue.advance(by: 2)

    runThrottledEffect(value: 3)

    mainQueue.advance()

    // A third value is emitted right away.
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testThrottleEmitsFirstValueOnce() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
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

    mainQueue.advance()

    // A value emits right away.
    XCTAssertNoDifference(values, [1])

    mainQueue.advance(by: 0.5)

    runThrottledEffect(value: 2)

    mainQueue.advance(by: 0.5)

    runThrottledEffect(value: 3)

    // A second value is emitted right away.
    XCTAssertNoDifference(values, [1, 2])
  }
}
