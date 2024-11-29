#if DEBUG
  @preconcurrency import Combine
  @testable @preconcurrency import ComposableArchitecture
  import XCTest

  final class DemandBufferTests: BaseTCATestCase {
    func testConcurrentSend() async throws {
      let values = LockIsolated<Set<Int>>([])

      let effect = AnyPublisher<Int, Never>.create { subscriber in
        Task.detached { @Sendable in
          for index in 0...1_000 {
            subscriber.send(index)
          }
          subscriber.send(completion: .finished)
        }
        return AnyCancellable {}
      }

      let cancellable = effect.sink { value in
        values.withValue {
          _ = $0.insert(value)
        }
      }

      try await Task.sleep(nanoseconds: NSEC_PER_SEC)

      XCTAssertEqual(values.value, Set(0...1_000))

      _ = cancellable
    }

    func testConcurrentDemandAndSend() async throws {
      let values = LockIsolated<Set<Int>>([])
      let subscriberLock = LockIsolated<Void>(())

      let effectSubscriber = LockIsolated<Effect<Int>.Subscriber?>(nil)
      let effect = AnyPublisher<Int, Never>.create { subscriber in
        effectSubscriber.setValue(subscriber)
        return AnyCancellable {}
      }

      let cancellable = effect.sink { value in
        values.withValue {
          _ = $0.insert(value)
        }
      }

      await withTaskGroup(of: Void.self) { group in
        for index in 0..<1_000 {
          group.addTask { @Sendable in
            effectSubscriber.value?.send(index)
          }
          group.addTask { @Sendable in
            subscriberLock.withValue { _ in
              _ = (effectSubscriber.value as? any Subscription)?.request(.max(1))
            }
          }
        }
      }

      try await Task.sleep(nanoseconds: NSEC_PER_SEC)

      XCTAssertEqual(values.value, Set(0..<1_000))

      _ = cancellable
    }

    func testReentrantSubscriber() async throws {
      let values = LockIsolated<Set<Int>>([])
      let effectSubscriber = LockIsolated<Effect<Int>.Subscriber?>(nil)

      let effect = AnyPublisher<Int, Never>.create { subscriber in
        effectSubscriber.setValue(subscriber)
        return AnyCancellable {}
      }

      let cancellable = effect.sink { value in
        values.withValue {
          _ = $0.insert(value)
        }
        if value < 1_000 {
          Task { @MainActor in
            effectSubscriber.value?.send(value + 1_000)
          }
        }
      }

      Task.detached { @Sendable in
        for index in 0..<1_000 {
          effectSubscriber.value?.send(index)
        }
      }

      try await Task.sleep(nanoseconds: NSEC_PER_SEC)

      XCTAssertEqual(values.value, Set(0..<2_000))

      _ = cancellable
    }

    func testNoDeadlockOnReentrantSend() {
      let values = LockIsolated<Set<Int>>([])
      let expectation = XCTestExpectation(description: "Test should not deadlock")

      let effectSubscriber = LockIsolated<Effect<Int>.Subscriber?>(nil)
      let effect = AnyPublisher<Int, Never>.create { subscriber in
        effectSubscriber.withValue { $0 = subscriber }
        return AnyCancellable {}
      }

      let cancellable = effect.sink { value in
        values.withValue {
          _ = $0.insert(value)
        }
        // Prevent infinite recursion by limiting re-entrant calls
        if value == 0 {
          effectSubscriber.withValue { $0?.send(value + 1_000) }
        } else {
          expectation.fulfill()
        }
      }

      // Ensure that 'effectSubscriber' is set before we use it
      effectSubscriber.withValue { subscriber in
        XCTAssertNotNil(subscriber)
        subscriber?.send(0)
      }

      // Wait for the test to complete
      wait(for: [expectation], timeout: 1.0)

      XCTAssertEqual(values.value, Set([0, 1_000]))

      _ = cancellable
    }

    func testConcurrentSendAndCompletion() {
      let values = LockIsolated<Set<Int>>([])
      let expectation = XCTestExpectation(description: "All values received")

      let effect = AnyPublisher<Int, Never>.create { subscriber in
        // Concurrently send values
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
          subscriber.send(index)
        }
        // Send completion
        DispatchQueue.global().async {
          subscriber.send(completion: .finished)
        }
        return AnyCancellable {}
      }

      let cancellable = effect.sink(
        receiveCompletion: { _ in expectation.fulfill() },
        receiveValue: { value in
          values.withValue {
            _ = $0.insert(value)
          }
        }
      )

      wait(for: [expectation], timeout: 5.0)

      XCTAssertEqual(values.value.count, 1000)

      _ = cancellable
    }
  }
#endif
