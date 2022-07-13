import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class EffectsBasicsTests: XCTestCase {
  func testLongLivingEffect() async {
    enum Action { case task }
    let store = TestStore(
      initialState: 0,
      reducer: Reducer<Int, Action, Void> { _, _, _ in
        .run { _ in try? await Task.sleep(nanoseconds: 1_000_000_000 * NSEC_PER_SEC) }
      },
      environment: ()
    )

    let task = store.send(.task)
    await task.cancel()
  }

  func testCountUpAndDown() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }

  func testNumberFact_HappyPath() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.environment.fact.fetchAsync = { "\($0) is a good number Brent" }

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
      $0.isNumberFactRequestInFlight = false
      $0.numberFact = "1 is a good number Brent"
    }
  }

  func testNumberFact_UnhappyPath() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    struct SomeError: Equatable, Error {}
    store.environment.fact.fetchAsync = { _ in throw SomeError() }

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await store.receive(.numberFactResponse(.failure(SomeError()))) {
      $0.isNumberFactRequestInFlight = false
    }
  }

  func testDecrement() async {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = mainQueue.eraseToAnyScheduler()

    store.send(.decrementButtonTapped) {
      $0.count = -1
    }

    print("Just before mainQueue.advance")
    await mainQueue.advance(by: .seconds(1))

    await store.receive(.decrementDelayResponse, timeout: 2*NSEC_PER_SEC) {
      $0.count = 0
    }
  }

  func testDecrementCancellation() async {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = mainQueue.eraseToAnyScheduler()

    store.send(.decrementButtonTapped) {
      $0.count = -1
    }
    store.send(.incrementButtonTapped) {
      $0.count = 0
    }
  }

  func testTimer() async {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = mainQueue.eraseToAnyScheduler()

    store.send(.startTimerButtonTapped) {
      $0.isTimerRunning = true
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.timerTick) {
      $0.count = 1
    }

    await mainQueue.advance(by: .milliseconds(950))
    await store.receive(.timerTick) {
      $0.count = 2
    }

    await mainQueue.advance(by: .milliseconds(900))
    await store.receive(.timerTick) {
      $0.count = 3
    }

    await mainQueue.advance(by: .milliseconds(850))
    await store.receive(.timerTick) {
      $0.count = 4
    }

    await mainQueue.advance(by: .milliseconds(800))
    await store.receive(.timerTick) {
      $0.count = 5
    }

    store.send(.stopTimerButtonTapped) {
      $0.isTimerRunning = false
    }
  }

  func testNthPrime() async {
    let store = TestStore(
      initialState: EffectsBasicsState(count: 200),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.send(.nthPrimeButtonTapped)

    await store.receive(.nthPrimeProgress(0.84)) {
      $0.nthPrimeProgress = 0.84
    }
    await store.receive(.nthPrimeResponse(1_223)) {
      $0.numberFact = "The 200th prime is 1223."
      $0.nthPrimeProgress = nil
    }

//    await task.finish()

    await store.finish()

//    await Task.yield()
    //await task.finish()
  }

  func testIsEquatable() {
    XCTAssertTrue(isEquatable(1))
    XCTAssertTrue(isEquatable("Hello"))
    XCTAssertTrue(isEquatable(true))

    XCTAssertFalse(isEquatable({ $0 + 1 }))
    XCTAssertFalse(isEquatable(()))
    XCTAssertFalse(isEquatable((1, 2)))
    XCTAssertFalse(isEquatable(VStack {}))

    XCTAssertTrue(equals(1, 1))
    XCTAssertTrue(equals("Hello", "Hello"))
    XCTAssertFalse(equals(true, false))
  }
}
import SwiftUI

extension EffectsBasicsEnvironment {
  static let unimplemented = Self(
    fact: .unimplemented,
    mainQueue: .unimplemented
  )
}

import Combine
import Foundation

/// A scheduler whose current time and execution can be controlled in a deterministic manner.
///
/// This scheduler is useful for testing how the flow of time effects publishers that use
/// asynchronous operators, such as `debounce`, `throttle`, `delay`, `timeout`, `receive(on:)`,
/// `subscribe(on:)` and more.
///
/// For example, consider the following `race` operator that runs two futures in parallel, but
/// only emits the first one that completes:
///
/// ```swift
/// func race<Output, Failure: Error>(
///   _ first: Future<Output, Failure>,
///   _ second: Future<Output, Failure>
/// ) -> AnyPublisher<Output, Failure> {
///   first
///     .merge(with: second)
///     .prefix(1)
///     .eraseToAnyPublisher()
/// }
/// ```
///
/// Although this publisher is quite simple we may still want to write some tests for it.
///
/// To do this we can create a test scheduler and create two futures, one that emits after a
/// second and one that emits after two seconds:
///
/// ```swift
/// let scheduler = DispatchQueue.test
/// let first = Future<Int, Never> { callback in
///   scheduler.schedule(after: scheduler.now.advanced(by: 1)) { callback(.success(1)) }
/// }
/// let second = Future<Int, Never> { callback in
///   scheduler.schedule(after: scheduler.now.advanced(by: 2)) { callback(.success(2)) }
/// }
/// ```
///
/// And then we can race these futures and collect their emissions into an array:
///
/// ```swift
/// var output: [Int] = []
/// let cancellable = race(first, second).sink { output.append($0) }
/// ```
///
/// And then we can deterministically move time forward in the scheduler to see how the publisher
/// emits. We can start by moving time forward by one second:
///
/// ```swift
/// scheduler.advance(by: 1)
/// XCTAssertEqual(output, [1])
/// ```
///
/// This proves that we get the first emission from the publisher since one second of time has
/// passed. If we further advance by one more second we can prove that we do not get anymore
/// emissions:
///
/// ```swift
/// scheduler.advance(by: 1)
/// XCTAssertEqual(output, [1])
/// ```
///
/// This is a very simple example of how to control the flow of time with the test scheduler,
/// but this technique can be used to test any publisher that involves Combine's asynchronous
/// operations.
///
public final class TestScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
where SchedulerTimeType: Strideable, SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible {

  private var lastSequence: UInt = 0
  public let minimumTolerance: SchedulerTimeType.Stride = .zero
  public private(set) var now: SchedulerTimeType
  private var scheduled: [(sequence: UInt, date: SchedulerTimeType, action: () -> Void)] = []

  /// Creates a test scheduler with the given date.
  ///
  /// - Parameter now: The current date of the test scheduler.
  public init(now: SchedulerTimeType) {
    self.now = now
  }

  /// Advances the scheduler by the given stride.
  ///
  /// - Parameter stride: A stride. By default this argument is `.zero`, which does not advance the
  ///   scheduler's time but does cause the scheduler to execute any units of work that are waiting
  ///   to be performed for right now.
  public func advance(by stride: SchedulerTimeType.Stride = .zero) {
    let finalDate = self.now.advanced(by: stride)

    while self.now <= finalDate {
      self.scheduled.sort { ($0.date, $0.sequence) < ($1.date, $1.sequence) }

      guard
        let next = self.scheduled.first,
        finalDate >= next.date
      else {
        self.now = finalDate
        return
      }

      self.now = next.date

      self.scheduled.removeFirst()
      next.action()
    }
  }

  @MainActor
  public func advance(by stride: SchedulerTimeType.Stride = .zero) async {
    let finalDate = self.now.advanced(by: stride)

    while self.now <= finalDate {
      for _ in 1...10 { await Task.yield() }
      self.scheduled.sort { ($0.date, $0.sequence) < ($1.date, $1.sequence) }

      guard
        let next = self.scheduled.first,
        finalDate >= next.date
      else {
        self.now = finalDate
        return
      }

      self.now = next.date

      self.scheduled.removeFirst()
      next.action()
    }
  }


  /// Runs the scheduler until it has no scheduled items left.
  ///
  /// This method is useful for proving exhaustively that your publisher eventually completes
  /// and does not run forever. For example, the following code will run an infinite loop forever
  /// because the timer never finishes:
  ///
  ///     let scheduler = DispatchQueue.test
  ///     Publishers.Timer(every: .seconds(1), scheduler: scheduler)
  ///       .autoconnect()
  ///       .sink { _ in print($0) }
  ///       .store(in: &cancellables)
  ///
  ///     scheduler.run() // Will never complete
  ///
  /// If you wanted to make sure that this publisher eventually completes you would need to
  /// chain on another operator that completes it when a certain condition is met. This can be
  /// done in many ways, such as using `prefix`:
  ///
  ///     let scheduler = DispatchQueue.test
  ///     Publishers.Timer(every: .seconds(1), scheduler: scheduler)
  ///       .autoconnect()
  ///       .prefix(3)
  ///       .sink { _ in print($0) }
  ///       .store(in: &cancellables)
  ///
  ///     scheduler.run() // Prints 3 times and completes.
  ///
  public func run() {
    while let date = self.scheduled.first?.date {
      self.advance(by: self.now.distance(to: date))
    }
  }

  public func schedule(
    after date: SchedulerTimeType,
    interval: SchedulerTimeType.Stride,
    tolerance _: SchedulerTimeType.Stride,
    options _: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) -> Cancellable {
    let sequence = self.nextSequence()

    func scheduleAction(for date: SchedulerTimeType) -> () -> Void {
      return { [weak self] in
        let nextDate = date.advanced(by: interval)
        self?.scheduled.append((sequence, nextDate, scheduleAction(for: nextDate)))
        action()
      }
    }

    self.scheduled.append((sequence, date, scheduleAction(for: date)))

    return AnyCancellable { [weak self] in
      self?.scheduled.removeAll(where: { $0.sequence == sequence })
    }
  }

  public func schedule(
    after date: SchedulerTimeType,
    tolerance _: SchedulerTimeType.Stride,
    options _: SchedulerOptions?,
    _ action: @escaping () -> Void
  ) {
    self.scheduled.append((self.nextSequence(), date, action))
  }

  public func schedule(options _: SchedulerOptions?, _ action: @escaping () -> Void) {
    self.scheduled.append((self.nextSequence(), self.now, action))
  }

  private func nextSequence() -> UInt {
    self.lastSequence += 1
    return self.lastSequence
  }
}

extension DispatchQueue {
  /// A test scheduler of dispatch queues.
  public static var test: TestSchedulerOf<DispatchQueue> {
    // NB: `DispatchTime(uptimeNanoseconds: 0) == .now())`. Use `1` for consistency.
    .init(now: .init(.init(uptimeNanoseconds: 1)))
  }
}

extension OperationQueue {
  /// A test scheduler of operation queues.
  public static var test: TestSchedulerOf<OperationQueue> {
    .init(now: .init(.init(timeIntervalSince1970: 0)))
  }
}

extension RunLoop {
  /// A test scheduler of run loops.
  public static var test: TestSchedulerOf<RunLoop> {
    .init(now: .init(.init(timeIntervalSince1970: 0)))
  }
}

/// A convenience type to specify a `TestScheduler` by the scheduler it wraps rather than by the
/// time type and options type.
public typealias TestSchedulerOf<Scheduler> = TestScheduler<
  Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions
> where Scheduler: Combine.Scheduler
