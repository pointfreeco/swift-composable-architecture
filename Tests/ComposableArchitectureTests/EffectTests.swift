import Combine
import XCTest

@testable import ComposableArchitecture

@MainActor
final class EffectTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []
  let mainQueue = DispatchQueue.test

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
      Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect(),
      Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect(),
      Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect()
    )

    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect: Effect<Int, Never> = Effect.concatenate(
      Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
    )

    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1])
  }

  func testConcatenateWithChainingList() {
    let effect: Effect<Int, Never> = Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
      .concatenate(
        Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect(),
        Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect()
      )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateByChaining() {
    let effect: Effect<Int, Never> = Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
      .concatenate(Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect())
      .concatenate(Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect())

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateWithArray() {
    let effect = Effect<Int, Never>.concatenate(
      [
        Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect(),
        Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect(),
        Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect()
      ]
    )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateWithClosure() {
    let effect = Effect<Int, Never>.concatenate {
      [
        Effect(value: 1).delay(for: 1, scheduler: self.mainQueue).eraseToEffect(),
        Effect(value: 2).delay(for: 2, scheduler: self.mainQueue).eraseToEffect(),
        Effect(value: 3).delay(for: 3, scheduler: self.mainQueue).eraseToEffect()
      ]
    }

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateWithChainingArray() {
    let effect: Effect<Int, Never> = Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
      .concatenate(
        [
          Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect(),
          Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect()
        ]
      )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateWithChainingClosure() {
    let effect: Effect<Int, Never> = Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
      .concatenate {
        [
          Effect(value: 2).delay(for: 2, scheduler: self.mainQueue).eraseToEffect(),
          Effect(value: 3).delay(for: 3, scheduler: self.mainQueue).eraseToEffect()
        ]
      }

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateOutputs() {
    let effect = Effect<Int, Never>.concatenateOutputs(1, 2, 3)

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateChainingOutputs() {
    let effect: Effect<Int, Never> = Effect(value: 1).concatenateOutputs(2, 3)

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateWithOutputArray() {
    let effect: Effect<Int, Never> = Effect.concatenateOutputs([1, 2, 3])

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateWithChainingOutputArray() {
    let effect: Effect<Int, Never> = Effect(value: 1).concatenateOutputs([2, 3])

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateWithOutputClosure() {
    let effect: Effect<Int, Never> = Effect.concatenateOutputs { [1, 2, 3] }

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateWithChainingOutputClosure() {
    let effect: Effect<Int, Never> = Effect(value: 1).concatenateOutputs { [2, 3] }

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMerge() {
    let effect = Effect<Int, Never>.merge(
      Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect(),
      Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect(),
      Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect()
    )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeOneEffect() {
    var values: [Int] = []

    let effect: Effect<Int, Never> = Effect.merge(
      Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
    )

    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1])
  }

  func testMergeWithChainingList() {
    let effect: Effect<Int, Never> = Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
      .merge(
        Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect(),
        Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect()
      )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeByChaining() {
    let effect: Effect<Int, Never> = Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
      .merge(Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect())
      .merge(Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect())

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeWithArray() {
    let effect = Effect<Int, Never>.merge(
      [
        Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect(),
        Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect(),
        Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect()
      ]
    )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeWithClosure() {
    let effect = Effect<Int, Never>.merge {
      [
        Effect(value: 1).delay(for: 1, scheduler: self.mainQueue).eraseToEffect(),
        Effect(value: 2).delay(for: 2, scheduler: self.mainQueue).eraseToEffect(),
        Effect(value: 3).delay(for: 3, scheduler: self.mainQueue).eraseToEffect()
      ]
    }

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeWithChainingArray() {
    let effect: Effect<Int, Never> = Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
      .merge(
        [
          Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect(),
          Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect()
        ]
      )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeWithChainingClosure() {
    let effect: Effect<Int, Never> = Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
      .merge {
        [
          Effect(value: 2).delay(for: 2, scheduler: self.mainQueue).eraseToEffect(),
          Effect(value: 3).delay(for: 3, scheduler: self.mainQueue).eraseToEffect()
        ]
      }

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeOutputs() {
    let effect = Effect<Int, Never>.mergeOutputs(1, 2, 3)

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeChainingOutputs() {
    let effect: Effect<Int, Never> = Effect(value: 1).mergeOutputs(2, 3)

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeWithOutputArray() {
    let effect: Effect<Int, Never> = Effect.mergeOutputs([1, 2, 3])

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeWithChainingOutputArray() {
    let effect: Effect<Int, Never> = Effect(value: 1).mergeOutputs([2, 3])

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeWithOutputClosure() {
    let effect: Effect<Int, Never> = Effect.mergeOutputs { [1, 2, 3] }

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testMergeWithChainingOutputClosure() {
    let effect: Effect<Int, Never> = Effect(value: 1).mergeOutputs { [2, 3] }

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testEffectSubscriberInitializer() {
    let effect = Effect<Int, Never>.run { subscriber in
      subscriber.send(1)
      subscriber.send(2)
      self.mainQueue.schedule(after: self.mainQueue.now.advanced(by: .seconds(1))) {
        subscriber.send(3)
      }
      self.mainQueue.schedule(after: self.mainQueue.now.advanced(by: .seconds(2))) {
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

    self.mainQueue.advance(by: 1)

    XCTAssertNoDifference(values, [1, 2, 3])
    XCTAssertNoDifference(isComplete, false)

    self.mainQueue.advance(by: 1)

    XCTAssertNoDifference(values, [1, 2, 3, 4])
    XCTAssertNoDifference(isComplete, true)
  }

  func testEffectSubscriberInitializer_WithCancellation() {
    enum CancelID {}

    let effect = Effect<Int, Never>.run { subscriber in
      subscriber.send(1)
      self.mainQueue.schedule(after: self.mainQueue.now.advanced(by: .seconds(1))) {
        subscriber.send(2)
      }

      return AnyCancellable {}
    }
    .cancellable(id: CancelID.self)

    var values: [Int] = []
    var isComplete = false
    effect
      .sink(receiveCompletion: { _ in isComplete = true }, receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertNoDifference(values, [1])
    XCTAssertNoDifference(isComplete, false)

    Effect<Void, Never>.cancel(id: CancelID.self)
      .sink(receiveValue: { _ in })
      .store(in: &self.cancellables)

    self.mainQueue.advance(by: 1)

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

  func testUnimplemented() {
    let effect = Effect<Never, Never>.unimplemented("unimplemented")
    XCTExpectFailure {
      effect
        .sink(receiveValue: { _ in })
        .store(in: &self.cancellables)
    } issueMatcher: { issue in
      issue.compactDescription == "unimplemented - An unimplemented effect ran."
    }
  }

  func testTask() {
    let expectation = self.expectation(description: "Complete")
    var result: Int?
    Effect<Int, Never>.task { @MainActor in
      expectation.fulfill()
      return 42
    }
    .sink(receiveValue: { result = $0 })
    .store(in: &self.cancellables)
    self.wait(for: [expectation], timeout: 1)
    XCTAssertNoDifference(result, 42)
  }

  func testCancellingTask_Infallible() {
    @Sendable func work() async -> Int {
      do {
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        XCTFail()
      } catch {
      }
      return 42
    }

    Effect<Int, Never>.task { await work() }
      .sink(
        receiveCompletion: { _ in XCTFail() },
        receiveValue: { _ in XCTFail() }
      )
      .store(in: &self.cancellables)

    self.cancellables = []

    _ = XCTWaiter.wait(for: [.init()], timeout: 1.1)
  }
}
