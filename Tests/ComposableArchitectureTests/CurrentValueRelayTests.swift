#if DEBUG
  @preconcurrency import Combine
  @testable @preconcurrency import ComposableArchitecture
  import XCTest

  final class CurrentValueRelayTests: BaseTCATestCase {
    func testConcurrentSend() async {
      nonisolated(unsafe) let subject = CurrentValueRelay(0)
      let values = LockIsolated<Set<Int>>([])
      let cancellable = subject.sink { (value: Int) in
        values.withValue {
          _ = $0.insert(value)
        }
      }

      await withTaskGroup(of: Void.self) { group in
        for index in 1...1_000 {
          group.addTask {
            subject.send(index)
          }
        }
      }

      XCTAssertEqual(values.value, Set(Array(0...1_000)))

      _ = cancellable
    }
  }
#endif
