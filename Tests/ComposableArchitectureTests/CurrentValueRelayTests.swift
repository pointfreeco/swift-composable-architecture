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
          group.addTask { @Sendable in
            subject.send(index)
          }
        }
      }

      XCTAssertEqual(values.value, Set(Array(0...1_000)))

      _ = cancellable
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func testConcurrentSendAndReceive() async {
      nonisolated(unsafe) let subject = CurrentValueRelay(0)
      let values = LockIsolated<Set<Int>>([])
      let cancellable = subject.sink { (value: Int) in
        values.withValue {
          _ = $0.insert(value)
        }
      }

      let receives = Task.detached { @Sendable in
        for await _ in subject.values {}
      }

      await withTaskGroup(of: Void.self) { group in
        for index in 1...1_000 {
          group.addTask { @Sendable in
            subject.send(index)
          }
        }
      }

      receives.cancel()
      _ = await receives.value

      XCTAssertEqual(values.value, Set(Array(0...1_000)))

      _ = cancellable
    }
  }
#endif
