import Combine
import XCTest

@testable import ComposableArchitecture

final class EffectTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []
  let scheduler = DispatchQueue.test

  func testCatchToEffect() {
    struct Error: Swift.Error, Equatable {}

    Future<Int, Error> { $0(.success(42)) }
      .catchToEffect()
      .sink { XCTAssertNoDifference($0, .success(42)) }
      .store(in: &self.cancellables)

    Future<Int, Error> { $0(.failure(Error())) }
      .catchToEffect()
      .sink { XCTAssertNoDifference($0, .failure(Error())) }
      .store(in: &self.cancellables)

    Future<Int, Never> { $0(.success(42)) }
      .eraseToEffect()
      .sink { XCTAssertNoDifference($0, 42) }
      .store(in: &self.cancellables)

    Future<Int, Error> { $0(.success(42)) }
      .catchToEffect {
        switch $0 {
        case let .success(val):
          return val
        case .failure:
          return -1
        }
      }
      .sink { XCTAssertNoDifference($0, 42) }
      .store(in: &self.cancellables)

    Future<Int, Error> { $0(.failure(Error())) }
      .catchToEffect {
        switch $0 {
        case let .success(val):
          return val
        case .failure:
          return -1
        }
      }
      .sink { XCTAssertNoDifference($0, -1) }
      .store(in: &self.cancellables)
  }

  func testConcatenate() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).delay(for: 1, scheduler: scheduler).eraseToEffect(),
      Effect(value: 2).delay(for: 2, scheduler: scheduler).eraseToEffect(),
      Effect(value: 3).delay(for: 3, scheduler: scheduler).eraseToEffect()
    )

    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.scheduler.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.scheduler.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.scheduler.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).delay(for: 1, scheduler: scheduler).eraseToEffect()
    )

    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.scheduler.run()
    XCTAssertNoDifference(values, [1])
  }

  func testMerge() {
    let effect = Effect<Int, Never>.merge(
      Effect(value: 1).delay(for: 1, scheduler: scheduler).eraseToEffect(),
      Effect(value: 2).delay(for: 2, scheduler: scheduler).eraseToEffect(),
      Effect(value: 3).delay(for: 3, scheduler: scheduler).eraseToEffect()
    )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testEffectSubscriberInitializer() {
    let effect = Effect<Int, Never>.run { subscriber in
      subscriber.send(1)
      subscriber.send(2)
      self.scheduler.schedule(after: self.scheduler.now.advanced(by: .seconds(1))) {
        subscriber.send(3)
      }
      self.scheduler.schedule(after: self.scheduler.now.advanced(by: .seconds(2))) {
        subscriber.send(4)
        subscriber.send(completion: .finished)
      }

      return AnyCancellable {}
    }

    var values: [Int] = []
    var isComplete = false
    effect
      .sink(receiveCompletion: { _ in isComplete = true }, receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2])
    XCTAssertNoDifference(isComplete, false)

    self.scheduler.advance(by: 1)

    XCTAssertNoDifference(values, [1, 2, 3])
    XCTAssertNoDifference(isComplete, false)

    self.scheduler.advance(by: 1)

    XCTAssertNoDifference(values, [1, 2, 3, 4])
    XCTAssertNoDifference(isComplete, true)
  }

  func testEffectSubscriberInitializer_WithCancellation() {
    struct CancelId: Hashable {}

    let effect = Effect<Int, Never>.run { subscriber in
      subscriber.send(1)
      self.scheduler.schedule(after: self.scheduler.now.advanced(by: .seconds(1))) {
        subscriber.send(2)
      }

      return AnyCancellable {}
    }
    .cancellable(id: CancelId())

    var values: [Int] = []
    var isComplete = false
    effect
      .sink(receiveCompletion: { _ in isComplete = true }, receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1])
    XCTAssertNoDifference(isComplete, false)

    Effect<Void, Never>.cancel(id: CancelId())
      .sink(receiveValue: { _ in })
      .store(in: &self.cancellables)

    self.scheduler.advance(by: 1)

    XCTAssertNoDifference(values, [1])
    XCTAssertNoDifference(isComplete, true)
  }

  func testEffectErrorCrash() {
    let expectation = self.expectation(description: "Complete")

    // This crashes on iOS 13 if Effect.init(error:) is implemented using the Fail publisher.
    Effect<Never, Error>(error: NSError(domain: "", code: 1))
      .retry(3)
      .catch { _ in Fail(error: NSError(domain: "", code: 1)) }
      .sink(
        receiveCompletion: { _ in expectation.fulfill() },
        receiveValue: { _ in }
      )
      .store(in: &self.cancellables)

    self.wait(for: [expectation], timeout: 0)
  }

  func testDoubleCancelInFlight() {
    var result: Int?

    _ = Just(42)
      .eraseToEffect()
      .cancellable(id: "id", cancelInFlight: true)
      .cancellable(id: "id", cancelInFlight: true)
      .sink { result = $0 }

    XCTAssertEqual(result, 42)
  }

  #if compiler(>=5.4)
    func testFailing() {
      let effect = Effect<Never, Never>.failing("failing")
      XCTExpectFailure {
        effect
          .sink(receiveValue: { _ in })
          .store(in: &self.cancellables)
      }
    }
  #endif

  #if canImport(_Concurrency) && compiler(>=5.5.2)
    func testTask() {
      let expectation = self.expectation(description: "Complete")
      var result: Int?
      Effect<Int, Never>.task {
        expectation.fulfill()
        return 42
      }
      .sink(receiveValue: { result = $0 })
      .store(in: &self.cancellables)
      self.wait(for: [expectation], timeout: 1)
      XCTAssertNoDifference(result, 42)
    }

    func testThrowingTask() {
      let expectation = self.expectation(description: "Complete")
      struct MyError: Error {}
      var result: Error?
      Effect<Int, Error>.task {
        expectation.fulfill()
        throw MyError()
      }
      .sink(
        receiveCompletion: {
          switch $0 {
          case .finished:
            XCTFail()
          case let .failure(error):
            result = error
          }
        },
        receiveValue: { _ in XCTFail() }
      )
      .store(in: &self.cancellables)
      self.wait(for: [expectation], timeout: 1)
      XCTAssertNotNil(result)
    }

    func testCancellingTask() {
      @Sendable func work() async throws -> Int {
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        XCTFail()
        return 42
      }

      Effect<Int, Error>.task { try await work() }
        .sink(
          receiveCompletion: { _ in XCTFail() },
          receiveValue: { _ in XCTFail() }
        )
        .store(in: &self.cancellables)

      self.cancellables = []

      _ = XCTWaiter.wait(for: [.init()], timeout: 1.1)
    }
  #endif
}
