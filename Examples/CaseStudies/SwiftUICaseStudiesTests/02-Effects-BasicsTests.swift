import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class EffectsBasicsTests: XCTestCase {
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

//    store.environment.fact.fetch = { Effect(value: "\($0) is a good number Brent") }
    store.environment.fact.fetchAsync = { "\($0) is a good number Brent" }
//    store.environment.mainQueue = .immediate

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
//    _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
    await store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
      $0.isNumberFactRequestInFlight = false
      $0.numberFact = "1 is a good number Brent"
    }

//    _ = { store.receive(.decrementButtonTapped) }()
  }

  func testNumberFact_UnhappyPath() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

//    store.environment.fact.fetch = { _ in Effect(error: FactClient.Failure()) }
    store.environment.fact.fetchAsync = { _ in throw FactClient.Failure() }

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await store.receive(.numberFactResponse(.failure(FactClient.Failure()))) {
      $0.isNumberFactRequestInFlight = false
    }
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

//    XCTAssertFalse(equals((), ()))
  }

  func testDecrement() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = .immediate

    store.send(.decrementButtonTapped) {
      $0.count = -1
    }
    await store.receive(.decrementDelayResponse, timeout: NSEC_PER_SEC*2) {
      $0.count = 0
    }
  }

  func testDecrement_WithTestSchedxuler() async {
    let scheduler = DispatchQueue.test

    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = scheduler.eraseToAnyScheduler()

    store.send(.decrementButtonTapped) {
      $0.count = -1
    }
//    await Task.yield()
//    await Task.yield()
//    await Task.yield()
//    for _ in 1...10 { await Task.yield() }

    await Task.detached(priority: .low) { await Task.yield() }.value
    await Task.detached(priority: .low) { await Task.yield() }.value
    await Task.detached(priority: .low) { await Task.yield() }.value

    print("Just before scheduler.advance")
    scheduler.advance(by: .seconds(1))
    await store.receive(.decrementDelayResponse, timeout: NSEC_PER_SEC*2) {
      $0.count = 0
    }
  }

  func testDecrementCancellation() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = .immediate

    store.send(.decrementButtonTapped) {
      $0.count = -1
    }
    store.send(.incrementButtonTapped) {
      $0.count = 0
    }
  }

  func testTimer() async throws {
    let scheduler = _TestScheduler<DispatchQueue.SchedulerTimeType, DispatchQueue.SchedulerOptions>(now: .init(.init(uptimeNanoseconds: 42)))

    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.environment.mainQueue = scheduler.eraseToAnyScheduler()

    store.send(.startTimerButtonTapped) {
      $0.isTimerRunning = true
    }

    await scheduler.advance(by: .seconds(1))
    await store.receive(.timerTick) {
      $0.count = 1
    }

    await scheduler.advance(by: .milliseconds(950))
    await store.receive(.timerTick) {
      $0.count = 2
    }
    await scheduler.advance(by: .milliseconds(900))
    await store.receive(.timerTick) {
      $0.count = 3
    }
    await scheduler.advance(by: .milliseconds(850))
    await store.receive(.timerTick) {
      $0.count = 4
    }
    await scheduler.advance(by: .milliseconds(800))
    await store.receive(.timerTick) {
      $0.count = 5
    }

    store.send(.stopTimerButtonTapped) {
      $0.isTimerRunning = false
    }
  }

  func testNthPrime() async throws {
    let store = TestStore(
      initialState: EffectsBasicsState(count: 200),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    let task = store.send(.nthPrimeButtonTapped)

    await store.receive(.nthPrime(.progress(0.84))) {
      $0.nthPrimeProgress = 0.84
    }
    await store.receive(.nthPrime(.response(1_223))) {
      $0.nthPrimeProgress = nil
      $0.numberFact = "The 200th prime is 1223."
    }

    await task.finish()
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
public final class _TestScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
where SchedulerTimeType: Strideable, SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible {

  private var lastSequence: UInt = 0
  public let minimumTolerance: SchedulerTimeType.Stride = .zero
  public private(set) var now: SchedulerTimeType
  private var scheduled: [(sequence: UInt, date: SchedulerTimeType, action: () -> Void)] = []

  public init(now: SchedulerTimeType) {
    self.now = now
  }
  @MainActor
  public func advance(by stride: SchedulerTimeType.Stride = .zero) async {
    let finalDate = self.now.advanced(by: stride)

    while self.now <= finalDate {
      for _ in 1...10 {
        await Task.detached(priority: .low) { await Task.yield() }.value
      }
      self.scheduled.sort { ($0.date, $0.sequence) < ($1.date, $1.sequence) }
      print(#file, #line)
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
