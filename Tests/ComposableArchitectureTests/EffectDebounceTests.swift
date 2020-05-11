import Combine
import ComposableArchitecture
import XCTest

final class EffectDebounceTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testDebounce() {
    let scheduler = DispatchQueue.testScheduler
    var values: [Int] = []

    func runDebouncedEffect(value: Int) {
      struct CancelToken: Hashable {}
      Just(value)
        .eraseToEffect()
        .debounce(id: CancelToken(), for: 1, scheduler: scheduler)
        .sink { values.append($0) }
        .store(in: &self.cancellables)
    }

    runDebouncedEffect(value: 1)

    // Nothing emits right away.
    XCTAssertEqual(values, [])

    // Waiting half the time also emits nothing
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [])

    // Run another debounced effect.
    runDebouncedEffect(value: 2)

    // Waiting half the time emits nothing because the first debounced effect has been canceled.
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [])

    // Run another debounced effect.
    runDebouncedEffect(value: 3)

    // Waiting half the time emits nothing because the second debounced effect has been canceled.
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [])

    // Waiting the rest of the time emits the final effect value.
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [3])

    // Running out the scheduler
    scheduler.run()
    XCTAssertEqual(values, [3])
  }

  func testDebounceIsLazy() {
    let scheduler = DispatchQueue.testScheduler
    var values: [Int] = []
    var effectRuns = 0

    func runDebouncedEffect(value: Int) {
      struct CancelToken: Hashable {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .debounce(id: CancelToken(), for: 1, scheduler: scheduler)
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runDebouncedEffect(value: 1)

    XCTAssertEqual(values, [])
    XCTAssertEqual(effectRuns, 0)

    scheduler.advance(by: 0.5)

    XCTAssertEqual(values, [])
    XCTAssertEqual(effectRuns, 0)

    scheduler.advance(by: 0.5)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(effectRuns, 1)
  }
}
