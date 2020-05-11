import Combine
import XCTest

@testable import ComposableArchitecture

final class EffectThrottleTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []
  let scheduler = DispatchQueue.testScheduler

  func testThrottleLatest() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
      struct CancelToken: Hashable {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .throttle(id: CancelToken(), for: 1, scheduler: scheduler.eraseToAnyScheduler(), latest: true)
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runThrottledEffect(value: 1)

    // A value emits right away.
    XCTAssertEqual(values, [1])

    runThrottledEffect(value: 2)

    // A second value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 3)

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 4)

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 5)

    // A third value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 0.25)

    // The latest value emits.
    XCTAssertEqual(values, [1, 5])
  }

  func testThrottleFirst() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
      struct CancelToken: Hashable {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .throttle(
        id: CancelToken(), for: 1, scheduler: scheduler.eraseToAnyScheduler(), latest: false
      )
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runThrottledEffect(value: 1)

    // A value emits right away.
    XCTAssertEqual(values, [1])

    runThrottledEffect(value: 2)

    // A second value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 3)

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 4)

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 5)

    // A third value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 0.25)

    // The first throttled value emits.
    XCTAssertEqual(values, [1, 2])
  }

  func testThrottleAfterInterval() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
      struct CancelToken: Hashable {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .throttle(id: CancelToken(), for: 1, scheduler: scheduler.eraseToAnyScheduler(), latest: true)
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runThrottledEffect(value: 1)

    // A value emits right away.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 2)

    runThrottledEffect(value: 2)

    // A second value is emitted right away.
    XCTAssertEqual(values, [1, 2])
  }
}
