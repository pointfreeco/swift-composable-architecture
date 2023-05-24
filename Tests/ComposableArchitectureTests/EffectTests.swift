import Combine
@_spi(Canary)@_spi(Internals) import ComposableArchitecture
@_spi(Concurrency) import Dependencies
import XCTest

@MainActor
final class EffectTests: BaseTCATestCase {
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

  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    func testConcatenate() async {
      await withMainSerialExecutor {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
          let clock = TestClock()
          var values: [Int] = []

          let effect = EffectPublisher<Int, Never>.concatenate(
            (1...3).map { count in
              .task {
                try await clock.sleep(for: .seconds(count))
                return count
              }
            }
          )

          effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

          XCTAssertEqual(values, [])

          await clock.advance(by: .seconds(1))
          XCTAssertEqual(values, [1])

          await clock.advance(by: .seconds(2))
          XCTAssertEqual(values, [1, 2])

          await clock.advance(by: .seconds(3))
          XCTAssertEqual(values, [1, 2, 3])

          await clock.run()
          XCTAssertEqual(values, [1, 2, 3])
        }
      }
    }
  #endif

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect = EffectTask<Int>.concatenate(
      .send(1).delay(for: 1, scheduler: mainQueue).eraseToEffect()
    )

    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertEqual(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.mainQueue.run()
    XCTAssertEqual(values, [1])
  }

  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    func testMerge() async {
      if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
        await withMainSerialExecutor {
          let clock = TestClock()

          let effect = EffectPublisher<Int, Never>.merge(
            (1...3).map { count in
              .task {
                try await clock.sleep(for: .seconds(count))
                return count
              }
            }
          )

          var values: [Int] = []
          effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

          XCTAssertEqual(values, [])

          await clock.advance(by: .seconds(1))
          XCTAssertEqual(values, [1])

          await clock.advance(by: .seconds(1))
          XCTAssertEqual(values, [1, 2])

          await clock.advance(by: .seconds(1))
          XCTAssertEqual(values, [1, 2, 3])
        }
      }
    }
  #endif

  func testEffectSubscriberInitializer() {
    let effect = EffectTask<Int>.run { subscriber in
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
    enum CancelID { case delay }

    let effect = EffectTask<Int>.run { subscriber in
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

    EffectTask<Void>.cancel(id: CancelID.delay)
      .sink(receiveValue: { _ in })
      .store(in: &self.cancellables)

    self.mainQueue.advance(by: 1)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, true)
  }

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
      let effect = EffectTask<Never>.unimplemented("unimplemented")
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
    let effect = EffectTask<Int>.task { 42 }
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

    EffectTask<Int>.task { await work() }
      .sink(
        receiveCompletion: { _ in XCTFail() },
        receiveValue: { _ in XCTFail() }
      )
      .store(in: &self.cancellables)

    self.cancellables = []

    _ = XCTWaiter.wait(for: [.init()], timeout: 1.1)
  }

  func testDependenciesTransferredToEffects_Task() async {
    struct Feature: ReducerProtocol {
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date) var date
      func reduce(into state: inout Int, action: Action) -> EffectTask<Action> {
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
    await withMainSerialExecutor {
      struct Feature: ReducerProtocol {
        enum Action: Equatable {
          case tap
          case response(Int)
        }
        @Dependency(\.date) var date
        func reduce(into state: inout Int, action: Action) -> EffectTask<Action> {
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
  }

  func testMap() async {
    @Dependency(\.date) var date
    let effect = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
    } operation: {
      EffectTask<Void>(value: ()).map { date() }
    }
    var output: Date?
    effect
      .sink { output = $0 }
      .store(in: &self.cancellables)
    XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))

    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      let effect = withDependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      } operation: {
        EffectTask<Void>.task {}.map { date() }
      }
      output = await effect.values.first(where: { _ in true })
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
