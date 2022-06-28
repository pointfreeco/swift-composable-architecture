import Combine
import ComposableArchitecture
import XCTest

final class EffectDebounceTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testDebounce() {
    let mainQueue = DispatchQueue.test
    var values: [Int] = []

    func runDebouncedEffect(value: Int) {
      struct CancelToken: Hashable {}
      Just(value)
        .eraseToEffect()
        .debounce(id: CancelToken(), for: 1, scheduler: mainQueue)
        .sink { values.append($0) }
        .store(in: &self.cancellables)
    }

    runDebouncedEffect(value: 1)

    // Nothing emits right away.
    XCTAssertNoDifference(values, [])

    // Waiting half the time also emits nothing
    mainQueue.advance(by: 0.5)
    XCTAssertNoDifference(values, [])

    // Run another debounced effect.
    runDebouncedEffect(value: 2)

    // Waiting half the time emits nothing because the first debounced effect has been canceled.
    mainQueue.advance(by: 0.5)
    XCTAssertNoDifference(values, [])

    // Run another debounced effect.
    runDebouncedEffect(value: 3)

    // Waiting half the time emits nothing because the second debounced effect has been canceled.
    mainQueue.advance(by: 0.5)
    XCTAssertNoDifference(values, [])

    // Waiting the rest of the time emits the final effect value.
    mainQueue.advance(by: 0.5)
    XCTAssertNoDifference(values, [3])

    // Running out the scheduler
    mainQueue.run()
    XCTAssertNoDifference(values, [3])
  }

  func testDebounceIsLazy() {
    let mainQueue = DispatchQueue.test
    var values: [Int] = []
    var effectRuns = 0

    func runDebouncedEffect(value: Int) {
      struct CancelToken: Hashable {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .debounce(id: CancelToken(), for: 1, scheduler: mainQueue)
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runDebouncedEffect(value: 1)

    XCTAssertNoDifference(values, [])
    XCTAssertNoDifference(effectRuns, 0)

    mainQueue.advance(by: 0.5)

    XCTAssertNoDifference(values, [])
    XCTAssertNoDifference(effectRuns, 0)

    mainQueue.advance(by: 0.5)

    XCTAssertNoDifference(values, [1])
    XCTAssertNoDifference(effectRuns, 1)
  }
}
