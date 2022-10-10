import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class EffectTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []
  let mainQueue = DispatchQueue.test

  func testCatchToEffect() {
    struct Error: Swift.Error, Equatable {}

    Future<Int, Error> { $0(.success(42)) }
      .catchToEffect()
      .sink { XCTAssertEqual($0, .success(42)) }
      .store(in: &self.cancellables)

    Future<Int, Error> { $0(.failure(Error())) }
      .catchToEffect()
      .sink { XCTAssertEqual($0, .failure(Error())) }
      .store(in: &self.cancellables)

    Future<Int, Never> { $0(.success(42)) }
      .eraseToEffect()
      .sink { XCTAssertEqual($0, 42) }
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
      .sink { XCTAssertEqual($0, 42) }
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
      .sink { XCTAssertEqual($0, -1) }
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

    XCTAssertEqual(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.mainQueue.advance(by: 2)
    XCTAssertEqual(values, [1, 2])

    self.mainQueue.advance(by: 3)
    XCTAssertEqual(values, [1, 2, 3])

    self.mainQueue.run()
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
    )

    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertEqual(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.mainQueue.run()
    XCTAssertEqual(values, [1])
  }

  func testMerge() {
    let effect = Effect<Int, Never>.merge(
      Effect(value: 1).delay(for: 1, scheduler: mainQueue).eraseToEffect(),
      Effect(value: 2).delay(for: 2, scheduler: mainQueue).eraseToEffect(),
      Effect(value: 3).delay(for: 3, scheduler: mainQueue).eraseToEffect()
    )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertEqual(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.mainQueue.advance(by: 1)
    XCTAssertEqual(values, [1, 2])

    self.mainQueue.advance(by: 1)
    XCTAssertEqual(values, [1, 2, 3])
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

    XCTAssertEqual(values, [1, 2])
    XCTAssertEqual(isComplete, false)

    self.mainQueue.advance(by: 1)

    XCTAssertEqual(values, [1, 2, 3])
    XCTAssertEqual(isComplete, false)

    self.mainQueue.advance(by: 1)

    XCTAssertEqual(values, [1, 2, 3, 4])
    XCTAssertEqual(isComplete, true)
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

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, false)

    Effect<Void, Never>.cancel(id: CancelID.self)
      .sink(receiveValue: { _ in })
      .store(in: &self.cancellables)

    self.mainQueue.advance(by: 1)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, true)
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

  #if DEBUG
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
  #endif

  func testTask() async {
    guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }
    let effect = Effect<Int, Never>.task { 42 }
    for await result in effect.values {
      XCTAssertEqual(result, 42)
    }
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

  func testDependenciesTransferredToEffects() async {
    struct Feature: ReducerProtocol {
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date) var date
      func reduce(into state: inout Int, action: Action) -> Effect<Action, Never> {
        switch action {
        case .tap:
          return .merge(
            .task {
              .response(Int(self.date.now.timeIntervalSinceReferenceDate))
            },
            .run { send in
              await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
            }
          )
        case let .response(value):
          state = value
          return .none
        }
      }
    }
    let store = TestStore(
      initialState: 0,
      reducer: Feature()
        .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1234567890)))
    )

    await store.send(.tap).finish()
    await store.receive(.response(1234567890)) {
      $0 = 1234567890
    }
    await store.receive(.response(1234567890))
  }

  func testMap() async {
    @Dependency(\.date) var date
    let effect = DependencyValues
      .withValue(\.date, .init { Date(timeIntervalSince1970: 1234567890) }) {
        Effect<Void, Never>(value: ())
          .map { date() }
      }
    var output: Date?
    effect
      .sink { output = $0 }
      .store(in: &self.cancellables)
    XCTAssertEqual(output, Date(timeIntervalSince1970: 1234567890))

    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      let effect = DependencyValues
        .withValue(\.date, .init { Date(timeIntervalSince1970: 1234567890) }) {
          Effect<Void, Never>.task {}
            .map { date() }
        }
      output = await effect.values.first(where: { _ in true })
      XCTAssertEqual(output, Date(timeIntervalSince1970: 1234567890))
    }
  }
}
