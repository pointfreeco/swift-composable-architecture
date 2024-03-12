import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

final class EffectDebounceTests: BaseTCATestCase {
  @MainActor
  func testDebounce() async {
    let mainQueue = DispatchQueue.test
    var values: [Int] = []

    @discardableResult
    func runDebouncedEffect(value: Int) -> Task<Void, Never> {
      Task {
        struct CancelToken: Hashable {}

        let effect = Effect.send(value)
          .debounce(id: CancelToken(), for: 1, scheduler: mainQueue)

        for await action in effect.actions {
          values.append(action)
        }
      }
    }

    runDebouncedEffect(value: 1)

    // Nothing emits right away.
    XCTAssertEqual(values, [])

    // Waiting half the time also emits nothing
    await mainQueue.advance(by: 0.5)
    XCTAssertEqual(values, [])

    // Run another debounced effect.
    runDebouncedEffect(value: 2)

    // Waiting half the time emits nothing because the first debounced effect has been canceled.
    await mainQueue.advance(by: 0.5)
    XCTAssertEqual(values, [])

    // Run another debounced effect.
    runDebouncedEffect(value: 3)

    // Waiting half the time emits nothing because the second debounced effect has been canceled.
    await mainQueue.advance(by: 0.5)
    XCTAssertEqual(values, [])

    // Waiting the rest of the time emits the final effect value.
    await mainQueue.advance(by: 0.5)
    XCTAssertEqual(values, [3])

    // Running out the scheduler
    await mainQueue.run()
    XCTAssertEqual(values, [3])
  }

  @MainActor
  func testDebounceIsLazy() async {
    let mainQueue = DispatchQueue.test
    var values: [Int] = []
    var effectRuns = 0

    @discardableResult
    func runDebouncedEffect(value: Int) -> Task<Void, Never> {
      Task {
        struct CancelToken: Hashable {}

        let effect = Effect.publisher {
          Deferred { () -> Just<Int> in
            effectRuns += 1
            return Just(1)
          }
        }
        .debounce(id: CancelToken(), for: 1, scheduler: mainQueue)

        for await action in effect.actions {
          values.append(action)
        }
      }
    }

    runDebouncedEffect(value: 1)

    XCTAssertEqual(values, [])
    XCTAssertEqual(effectRuns, 0)

    await mainQueue.advance(by: 0.5)

    XCTAssertEqual(values, [])
    XCTAssertEqual(effectRuns, 0)

    await mainQueue.advance(by: 0.5)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(effectRuns, 1)
  }
}
