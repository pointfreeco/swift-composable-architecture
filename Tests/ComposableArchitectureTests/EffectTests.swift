import Combine
@_spi(Canary)@_spi(Internals) import ComposableArchitecture
import XCTest

@MainActor
final class EffectTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []
  let mainQueue = DispatchQueue.test

  @available(*, deprecated)
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

  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    func testConcatenate() async {
      if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
        let clock = TestClock()
        let values = LockIsolated<[Int]>([])

        let effect = EffectTask<Int>.concatenate(
          (1...3).map { count in
            .task {
              try await clock.sleep(for: .seconds(count))
              return count
            }
          }
        )

        let task = Task {
          for await n in effect.actions {
            values.withValue { $0.append(n) }
          }
        }

        XCTAssertEqual(values.value, [])

        await clock.advance(by: .seconds(1))
        XCTAssertEqual(values.value, [1])

        await clock.advance(by: .seconds(2))
        XCTAssertEqual(values.value, [1, 2])

        await clock.advance(by: .seconds(3))
        XCTAssertEqual(values.value, [1, 2, 3])

        await clock.run()
        XCTAssertEqual(values.value, [1, 2, 3])

        await task.value
      }
    }
  #endif

  func testConcatenateOneEffect() async {
    let values = LockIsolated<[Int]>([])

    let effect = Effect<Int>.concatenate(
      .publisher { Just(1).delay(for: 1, scheduler: self.mainQueue) }
    )

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    XCTAssertEqual(values.value, [])

    await self.mainQueue.advance(by: 1)
    XCTAssertEqual(values.value, [1])

    await self.mainQueue.run()
    XCTAssertEqual(values.value, [1])

    await task.value
  }

  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    func testMerge() async {
      if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
        let clock = TestClock()

        let effect = EffectPublisher<Int, Never>.merge(
          (1...3).map { count in
            .task {
              try await clock.sleep(for: .seconds(count))
              return count
            }
          }
        )

        let values = LockIsolated<[Int]>([])

        let task = Task {
          for await n in effect.actions {
            values.withValue { $0.append(n) }
          }
        }

        XCTAssertEqual(values.value, [])

        await clock.advance(by: .seconds(1))
        XCTAssertEqual(values.value, [1])

        await clock.advance(by: .seconds(1))
        XCTAssertEqual(values.value, [1, 2])

        await clock.advance(by: .seconds(1))
        XCTAssertEqual(values.value, [1, 2, 3])

        await task.value
      }
    }
  #endif

  @available(*, deprecated)
  func testEffectSubscriberInitializer() {
    let effect = Effect<Int>.run { subscriber in
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

  @available(*, deprecated)
  func testEffectSubscriberInitializer_WithCancellation() {
    enum CancelID { case delay }

    let effect = Effect<Int>.run { subscriber in
      subscriber.send(1)
      self.mainQueue.schedule(after: self.mainQueue.now.advanced(by: .seconds(1))) {
        subscriber.send(2)
      }

      return AnyCancellable {}
    }
    .cancellable(id: CancelID.delay)

    var values: [Int] = []
    var isComplete = false
    effect
      .sink(receiveCompletion: { _ in isComplete = true }, receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, false)

    Effect<Void>.cancel(id: CancelID.delay)
      .sink(receiveValue: { _ in })
      .store(in: &self.cancellables)

    self.mainQueue.advance(by: 1)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, true)
  }

  @available(*, deprecated)
  func testEffectErrorCrash() {
    let expectation = self.expectation(description: "Complete")

    // This crashes on iOS 13 if Effect.init(error:) is implemented using the Fail publisher.
    EffectPublisher<Never, Error>(error: NSError(domain: "", code: 1))
      .retry(3)
      .catch { _ in Fail(error: NSError(domain: "", code: 1)) }
      .sink(
        receiveCompletion: { _ in expectation.fulfill() },
        receiveValue: { _ in }
      )
      .store(in: &self.cancellables)

    self.wait(for: [expectation], timeout: 0)
  }

  func testDoubleCancelInFlight() async {
    var result: Int?

    let effect = Effect.send(42)
      .cancellable(id: "id", cancelInFlight: true)
      .cancellable(id: "id", cancelInFlight: true)

    for await n in effect.actions {
      XCTAssertNil(result)
      result = n
    }

    XCTAssertEqual(result, 42)
  }

  #if DEBUG
    @available(*, deprecated)
    func testUnimplemented() {
      let effect = Effect<Never>.unimplemented("unimplemented")
      XCTExpectFailure {
        effect
          .sink(receiveValue: { _ in })
          .store(in: &self.cancellables)
      } issueMatcher: { issue in
        issue.compactDescription == "unimplemented - An unimplemented effect ran."
      }
    }
  #endif

  @available(*, deprecated)
  func testTask() async {
    guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }
    let effect = Effect<Int>.task { 42 }
    for await result in effect.actions {
      XCTAssertEqual(result, 42)
    }
  }

  @available(*, deprecated)
  func testCancellingTask_Infallible() {
    @Sendable func work() async -> Int {
      do {
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        XCTFail()
      } catch {
      }
      return 42
    }

    Effect<Int>.task { await work() }
      .sink(
        receiveCompletion: { _ in XCTFail() },
        receiveValue: { _ in XCTFail() }
      )
      .store(in: &self.cancellables)

    self.cancellables = []

    _ = XCTWaiter.wait(for: [.init()], timeout: 1.1)
  }

  func testDependenciesTransferredToEffects_Task() async {
    struct Feature: Reducer {
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date) var date
      func reduce(into state: inout Int, action: Action) -> Effect<Action> {
        switch action {
        case .tap:
          return .task {
            .response(Int(self.date.now.timeIntervalSinceReferenceDate))
          }
        case let .response(value):
          state = value
          return .none
        }
      }
    }
    let store = TestStore(initialState: 0) {
      Feature()
        .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
    }

    await store.send(.tap).finish(timeout: NSEC_PER_SEC)
    await store.receive(.response(1_234_567_890)) {
      $0 = 1_234_567_890
    }
  }

  func testDependenciesTransferredToEffects_Run() async {
    struct Feature: Reducer {
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date) var date
      func reduce(into state: inout Int, action: Action) -> Effect<Action> {
        switch action {
        case .tap:
          return .run { send in
            await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
          }
        case let .response(value):
          state = value
          return .none
        }
      }
    }
    let store = TestStore(initialState: 0) {
      Feature()
        .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
    }

    await store.send(.tap).finish(timeout: NSEC_PER_SEC)
    await store.receive(.response(1_234_567_890)) {
      $0 = 1_234_567_890
    }
  }

  func testMap() async {
    @Dependency(\.date) var date
    let effect = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
    } operation: {
      Effect.send(()).map { date() }
    }
    var output: Date?
    for await date in effect.actions {
      XCTAssertNil(output)
      output = date
    }
    XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))

    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      let effect = withDependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      } operation: {
        Effect<Void>.task {}.map { date() }
      }
      output = nil
      for await date in effect.actions {
        XCTAssertNil(output)
        output = date
      }
      XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))
    }
  }

  func testCanary1() async {
    for _ in 1...100 {
      let task = TestStoreTask(rawValue: Task {}, timeout: NSEC_PER_SEC)
      await task.finish()
    }
  }
  func testCanary2() async {
    for _ in 1...100 {
      let task = TestStoreTask(rawValue: nil, timeout: NSEC_PER_SEC)
      await task.finish()
    }
  }
}
