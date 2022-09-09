import Combine
import CombineSchedulers
import ComposableArchitecture
import XCTest

@MainActor
final class ComposableArchitectureTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testScheduling() async {
    enum CounterAction: Equatable {
      case incrAndSquareLater
      case incrNow
      case squareNow
    }

    let counterReducer = Reducer<Int, CounterAction, AnySchedulerOf<DispatchQueue>> {
      state, action, mainQueue in
      switch action {
      case .incrAndSquareLater:
        return .merge(
          Effect(value: .incrNow)
            .delay(for: 2, scheduler: mainQueue)
            .eraseToEffect(),
          Effect(value: .squareNow)
            .delay(for: 1, scheduler: mainQueue)
            .eraseToEffect(),
          Effect(value: .squareNow)
            .delay(for: 2, scheduler: mainQueue)
            .eraseToEffect()
        )
      case .incrNow:
        state += 1
        return .none
      case .squareNow:
        state *= state
        return .none
      }
    }

    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: 2,
      reducer: counterReducer,
      environment: mainQueue.eraseToAnyScheduler()
    )

    await store.send(.incrAndSquareLater)
    await mainQueue.advance(by: 1)
    await store.receive(.squareNow) { $0 = 4 }
    await mainQueue.advance(by: 1)
    await store.receive(.incrNow) { $0 = 5 }
    await store.receive(.squareNow) { $0 = 25 }

    await store.send(.incrAndSquareLater)
    await mainQueue.advance(by: 2)
    await store.receive(.squareNow) { $0 = 625 }
    await store.receive(.incrNow) { $0 = 626 }
    await store.receive(.squareNow) { $0 = 391876 }
  }

  func testSimultaneousWorkOrdering() {
    let mainQueue = DispatchQueue.test

    var values: [Int] = []
    mainQueue.schedule(after: mainQueue.now, interval: 1) { values.append(1) }
      .store(in: &self.cancellables)
    mainQueue.schedule(after: mainQueue.now, interval: 2) { values.append(42) }
      .store(in: &self.cancellables)

    XCTAssertNoDifference(values, [])
    mainQueue.advance()
    XCTAssertNoDifference(values, [1, 42])
    mainQueue.advance(by: 2)
    XCTAssertNoDifference(values, [1, 42, 1, 1, 42])
  }

  func testLongLivingEffects() async {
    typealias Environment = (
      startEffect: Effect<Void, Never>,
      stopEffect: Effect<Never, Never>
    )

    enum Action { case end, incr, start }

    let reducer = Reducer<Int, Action, Environment> { state, action, environment in
      switch action {
      case .end:
        return environment.stopEffect.fireAndForget()
      case .incr:
        state += 1
        return .none
      case .start:
        return environment.startEffect.map { Action.incr }
      }
    }

    let subject = PassthroughSubject<Void, Never>()

    let store = TestStore(
      initialState: 0,
      reducer: reducer,
      environment: (
        startEffect: subject.eraseToEffect(),
        stopEffect: .fireAndForget { subject.send(completion: .finished) }
      )
    )

    await store.send(.start)
    await store.send(.incr) { $0 = 1 }
    subject.send()
    await store.receive(.incr) { $0 = 2 }
    await store.send(.end)
  }

  func testCancellation() async {
    let mainQueue = DispatchQueue.test

    enum Action: Equatable {
      case cancel
      case incr
      case response(Int)
    }

    let reducer = Reducer<Int, Action, Void> { state, action, _ in
      enum CancelID {}

      switch action {
      case .cancel:
        return .cancel(id: CancelID.self)

      case .incr:
        state += 1
        return .task { [state] in
          try await mainQueue.sleep(for: .seconds(1))
          return .response(state * state)
        }
        .cancellable(id: CancelID.self)

      case let .response(value):
        state = value
        return .none
      }
    }

    let store = TestStore(
      initialState: 0,
      reducer: reducer,
      environment: ()
    )

    await store.send(.incr) { $0 = 1 }
    await mainQueue.advance(by: .seconds(1))
    await store.receive(.response(1))

    await store.send(.incr) { $0 = 2 }
    await store.send(.cancel)
    await store.finish()
  }
}
