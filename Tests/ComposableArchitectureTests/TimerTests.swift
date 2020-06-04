import Combine
import ComposableArchitecture
import XCTest

final class TimerTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testTimer() {
    let scheduler = DispatchQueue.testScheduler

    var count = 0

    Effect.timer(id: 1, every: .seconds(1), on: scheduler)
      .sink { _ in count += 1 }
      .store(in: &self.cancellables)

    scheduler.advance(by: 1)
    XCTAssertEqual(count, 1)

    scheduler.advance(by: 1)
    XCTAssertEqual(count, 2)

    scheduler.advance(by: 1)
    XCTAssertEqual(count, 3)

    scheduler.advance(by: 3)
    XCTAssertEqual(count, 6)
  }

  func testInterleavingTimer() {
    let scheduler = DispatchQueue.testScheduler

    var count2 = 0
    var count3 = 0

    Effect.merge(
      Effect.timer(id: 1, every: .seconds(2), on: scheduler)
        .handleEvents(receiveOutput: { _ in count2 += 1 })
        .eraseToEffect(),
      Effect.timer(id: 2, every: .seconds(3), on: scheduler)
        .handleEvents(receiveOutput: { _ in count3 += 1 })
        .eraseToEffect()
    )
    .sink { _ in }
    .store(in: &self.cancellables)

    scheduler.advance(by: 1)
    XCTAssertEqual(count2, 0)
    XCTAssertEqual(count3, 0)
    scheduler.advance(by: 1)
    XCTAssertEqual(count2, 1)
    XCTAssertEqual(count3, 0)
    scheduler.advance(by: 1)
    XCTAssertEqual(count2, 1)
    XCTAssertEqual(count3, 1)
    scheduler.advance(by: 1)
    XCTAssertEqual(count2, 2)
    XCTAssertEqual(count3, 1)
  }

  func testTimerCancellation() {
    let scheduler = DispatchQueue.testScheduler

    var count2 = 0
    var count3 = 0

    struct CancelToken: Hashable {}

    Effect.merge(
      Effect.timer(id: CancelToken(), every: .seconds(2), on: scheduler)
        .handleEvents(receiveOutput: { _ in count2 += 1 })
        .eraseToEffect(),
      Effect.timer(id: CancelToken(), every: .seconds(3), on: scheduler)
        .handleEvents(receiveOutput: { _ in count3 += 1 })
        .eraseToEffect(),
      Just(())
        .delay(for: 30, scheduler: scheduler)
        .flatMap { Effect.cancel(id: CancelToken()) }
        .eraseToEffect()
    )
    .sink { _ in }
    .store(in: &self.cancellables)

    scheduler.advance(by: 1)

    XCTAssertEqual(count2, 0)
    XCTAssertEqual(count3, 0)

    scheduler.advance(by: 1)

    XCTAssertEqual(count2, 1)
    XCTAssertEqual(count3, 0)

    scheduler.advance(by: 1)

    XCTAssertEqual(count2, 1)
    XCTAssertEqual(count3, 1)

    scheduler.advance(by: 1)

    XCTAssertEqual(count2, 2)
    XCTAssertEqual(count3, 1)

    scheduler.run()

    XCTAssertEqual(count2, 15)
    XCTAssertEqual(count3, 10)
  }

  func testTimerCompletion() {
    let scheduler = DispatchQueue.testScheduler

    var count = 0

    Effect.timer(id: 1, every: .seconds(1), on: scheduler)
      .prefix(3)
      .sink { _ in count += 1 }
      .store(in: &self.cancellables)

    scheduler.advance(by: 1)
    XCTAssertEqual(count, 1)

    scheduler.advance(by: 1)
    XCTAssertEqual(count, 2)

    scheduler.advance(by: 1)
    XCTAssertEqual(count, 3)

    scheduler.run()
    XCTAssertEqual(count, 3)
  }
}
