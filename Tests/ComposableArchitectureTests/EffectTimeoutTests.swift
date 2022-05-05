import Combine
import ComposableArchitecture
import XCTest

final class EffectTimeoutTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testDebounce() {
    let scheduler = DispatchQueue.test
    var values: [Int] = []

    func runTimeoutEffect(value: Int) {
      struct CancelToken: Hashable {}
      Empty<Int,Error>(completeImmediately: false)
        .eraseToEffect()
        .timeout(id: CancelToken(), for: 1, scheduler: scheduler,
                 customError: {NSError(domain: "timeout error", code: 0)})
        .catch({ _ in
            Just(value)
        })
        .sink { values.append($0) }
        .store(in: &self.cancellables)
    }

    runTimeoutEffect(value: 1)

    // Nothing emits right away.
    XCTAssertNoDifference(values, [])

    // Waiting half the time also emits nothing
    scheduler.advance(by: 0.5)
    XCTAssertNoDifference(values, [])
      
    // Run another timeouted effect.
    runTimeoutEffect(value: 2)

    // Waiting half the time emits nothing because the first timeout effect has been canceled.
    scheduler.advance(by: 0.5)
    XCTAssertNoDifference(values, [])


    // Waiting the rest of the time emits the final effect value.
    scheduler.advance(by: 0.5)
    XCTAssertNoDifference(values, [2])

    // Running out the scheduler
    scheduler.run()
    XCTAssertNoDifference(values, [2])
  }
}
