import Combine
import ComposableArchitecture
import XCTest

final class EffectDelayTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []
  
  func testDelay() {
    let scheduler = DispatchQueue.test
    var values: [Int] = []
    
    func runDelayedEffect(value: Int) {
      struct CancelToken: Hashable {}
      Just(value)
        .eraseToEffect()
        .deferred(for: 1, scheduler: scheduler)
        .sink { values.append($0) }
        .store(in: &self.cancellables)
    }
    
    runDelayedEffect(value: 1)
    
    // Nothing emits right away.
    XCTAssertEqual(values, [])
    
    // Waiting half the time also emits nothing
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [])
    
    // Run another delayed effect.
    runDelayedEffect(value: 2)
    
    // Waiting half the time emits first delayed effect received.
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [1])
    
    // Run another delayed effect.
    runDelayedEffect(value: 3)
    
    // Waiting half the time emits second delayed effect received.
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [1, 2])
    
    // Waiting the rest of the time emits the final effect value.
    scheduler.advance(by: 0.5)
    XCTAssertEqual(values, [1, 2, 3])
    
    // Running out the scheduler
    scheduler.run()
    XCTAssertEqual(values, [1, 2, 3])
  }
  
  func testDelayIsLazy() {
    let scheduler = DispatchQueue.test
    var values: [Int] = []
    var effectRuns = 0
    
    func runDelayedEffect(value: Int) {
      struct CancelToken: Hashable {}
      
      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .deferred(for: 1, scheduler: scheduler)
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }
    
    runDelayedEffect(value: 1)
    
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
