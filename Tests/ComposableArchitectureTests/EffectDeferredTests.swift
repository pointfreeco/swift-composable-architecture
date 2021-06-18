import Combine
import ComposableArchitecture
import XCTest

final class EffectDeferredTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []
  
  func testDeferred() {
    let scheduler = DispatchQueue.test
    var values: [Int] = []
    
    func runDeferredEffect(value: Int) {
      Just(value)
        .eraseToEffect()
        .deferred(for: 1, scheduler: scheduler)
        .sink { values.append($0) }
        .store(in: &self.cancellables)
    }
    
    runDeferredEffect(value: 1)
    
    // Nothing emits right away.
    XCTAssertEqual(values, [])
    
    // Waiting half the time also emits nothing
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [])
    
    // Run another deferred effect.
    runDeferredEffect(value: 2)
    
    // Waiting half the time emits first deferred effect received.
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [1])
    
    // Run another deferred effect.
    runDeferredEffect(value: 3)
    
    // Waiting half the time emits second deferred effect received.
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [1, 2])
    
    // Waiting the rest of the time emits the final effect value.
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [1, 2, 3])
    
    // Running out the scheduler
    scheduler.run()
    XCTAssertEqual(values, [1, 2, 3])
  }
  
  func testDeferredIsLazy() {
    let scheduler = DispatchQueue.test
    var values: [Int] = []
    var effectRuns = 0
    
    func runDeferredEffect(value: Int) {
      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .deferred(for: 1, scheduler: scheduler)
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }
    
    runDeferredEffect(value: 1)
    
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
