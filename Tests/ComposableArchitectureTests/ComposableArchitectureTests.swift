import ComposableArchitecture
import XCTest
import RxSwift
import RxTest

final class ComposableArchitectureTests: XCTestCase {
  var disposeBag = DisposeBag()

  func testScheduling() {
    enum CounterAction: Equatable {
      case incrAndSquareLater
      case incrNow
      case squareNow
    }

    let counterReducer = Reducer<Int, CounterAction, SchedulerType> {
      state, action, scheduler in
      switch action {
      case .incrAndSquareLater:
        return .merge(
          Effect(value: .incrNow)
            .delay(.seconds(2), scheduler: scheduler)
            .eraseToEffect(),
          Effect(value: .squareNow)
            .delay(.seconds(1), scheduler: scheduler)
            .eraseToEffect(),
          Effect(value: .squareNow)
            .delay(.seconds(2), scheduler: scheduler)
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

    let scheduler = TestScheduler.default()

    let store = TestStore(
      initialState: 2,
      reducer: counterReducer,
      environment: scheduler
    )

    store.assert(
      .send(.incrAndSquareLater),
      .do { scheduler.advance(by: 1) },
      .receive(.squareNow) { $0 = 4 },
      .do { scheduler.advance(by: 1) },
      .receive(.incrNow) { $0 = 5 },
      .receive(.squareNow) { $0 = 25 }
    )

    store.assert(
      .send(.incrAndSquareLater),
      .do { scheduler.advance(by: 2) },
      .receive(.squareNow) { $0 = 625 },
      .receive(.incrNow) { $0 = 626 },
      .receive(.squareNow) { $0 = 391876 }
    )
  }

  func testLongLivingEffects() {
    typealias Environment = (
      startEffect: Effect<Void>,
      stopEffect: Effect<Never>
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

    let subject = PublishSubject<Void>()

    let store = TestStore(
      initialState: 0,
      reducer: reducer,
      environment: (
        startEffect: subject.eraseToEffect(),
        stopEffect: .fireAndForget { subject.onCompleted() }
      )
    )

    store.assert(
      .send(.start),
      .send(.incr) { $0 = 1 },
      .do { subject.onNext(()) },
      .receive(.incr) { $0 = 2 },
      .send(.end)
    )
  }

  func testCancellation() {
    enum Action: Equatable {
      case cancel
      case incr
      case response(Int)
    }

    struct Environment {
      let fetch: (Int) -> Effect<Int>
      let mainQueue: SchedulerType
    }

    let reducer = Reducer<Int, Action, Environment> { state, action, environment in
      struct CancelId: Hashable {}

      switch action {
      case .cancel:
        return .cancel(id: CancelId())

      case .incr:
        state += 1
        return environment.fetch(state)
          .observeOn(environment.mainQueue)
          .map(Action.response)
          .eraseToEffect()
          .cancellable(id: CancelId())

      case let .response(value):
        state = value
        return .none
      }
    }

    let scheduler = TestScheduler.default()

    let store = TestStore(
      initialState: 0,
      reducer: reducer,
      environment: Environment(
        fetch: { value in Effect(value: value * value) },
        mainQueue: scheduler
      )
    )

    store.assert(
      .send(.incr) { $0 = 1 },
      .do { scheduler.advance() },
      .receive(.response(1)) { $0 = 1 }
    )

    store.assert(
      .send(.incr) { $0 = 2 },
      .send(.cancel),
      .do { scheduler.run() }
    )
  }
}
