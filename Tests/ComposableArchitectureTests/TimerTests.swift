import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class TimerTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testTimer() async {
    let mainQueue = DispatchQueue.test

    var count = 0

    EffectPublisher.timer(id: 1, every: .seconds(1), on: mainQueue)
      .sink { _ in count += 1 }
      .store(in: &self.cancellables)

    await mainQueue.advance(by: 1)
    XCTAssertEqual(count, 1)

    await mainQueue.advance(by: 1)
    XCTAssertEqual(count, 2)

    await mainQueue.advance(by: 1)
    XCTAssertEqual(count, 3)

    await mainQueue.advance(by: 3)
    XCTAssertEqual(count, 6)
  }

  func testInterleavingTimer() async {
    let mainQueue = DispatchQueue.test

    var count2 = 0
    var count3 = 0

    EffectPublisher.merge(
      EffectPublisher.timer(id: 1, every: .seconds(2), on: mainQueue)
        .handleEvents(receiveOutput: { _ in count2 += 1 })
        .eraseToEffect(),
      EffectPublisher.timer(id: 2, every: .seconds(3), on: mainQueue)
        .handleEvents(receiveOutput: { _ in count3 += 1 })
        .eraseToEffect()
    )
    .sink { _ in }
    .store(in: &self.cancellables)

    await mainQueue.advance(by: 1)
    XCTAssertEqual(count2, 0)
    XCTAssertEqual(count3, 0)
    await mainQueue.advance(by: 1)
    XCTAssertEqual(count2, 1)
    XCTAssertEqual(count3, 0)
    await mainQueue.advance(by: 1)
    XCTAssertEqual(count2, 1)
    XCTAssertEqual(count3, 1)
    await mainQueue.advance(by: 1)
    XCTAssertEqual(count2, 2)
    XCTAssertEqual(count3, 1)
  }

  func testTimerCancellation() async {
    let mainQueue = DispatchQueue.test

    var firstCount = 0
    var secondCount = 0

    struct CancelToken: Hashable {}

    EffectPublisher.timer(id: CancelToken(), every: .seconds(2), on: mainQueue)
      .handleEvents(receiveOutput: { _ in firstCount += 1 })
      .eraseToEffect()
      .sink { _ in }
      .store(in: &self.cancellables)

    await mainQueue.advance(by: 2)

    XCTAssertEqual(firstCount, 1)

    await mainQueue.advance(by: 2)

    XCTAssertEqual(firstCount, 2)

    EffectPublisher.timer(id: CancelToken(), every: .seconds(2), on: mainQueue)
      .handleEvents(receiveOutput: { _ in secondCount += 1 })
      .eraseToEffect()
      .sink { _ in }
      .store(in: &self.cancellables)

    await mainQueue.advance(by: 2)

    XCTAssertEqual(firstCount, 2)
    XCTAssertEqual(secondCount, 1)

    await mainQueue.advance(by: 2)

    XCTAssertEqual(firstCount, 2)
    XCTAssertEqual(secondCount, 2)
  }

  func testTimerCompletion() async {
    let mainQueue = DispatchQueue.test

    var count = 0

    EffectPublisher.timer(id: 1, every: .seconds(1), on: mainQueue)
      .prefix(3)
      .sink { _ in count += 1 }
      .store(in: &self.cancellables)

    await mainQueue.advance(by: 1)
    XCTAssertEqual(count, 1)

    await mainQueue.advance(by: 1)
    XCTAssertEqual(count, 2)

    await mainQueue.advance(by: 1)
    XCTAssertEqual(count, 3)

    await mainQueue.run()
    XCTAssertEqual(count, 3)
  }
}
