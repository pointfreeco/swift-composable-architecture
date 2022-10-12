import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class TestStoreNonExhaustiveTests: XCTestCase {
  func testSkipReceivedActions() {
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Bool> { _, action in
        action ? .init(value: false) : .none
      }
    )

    store.send(true)
    store.skipReceivedActions()
  }

  func testSkipInFlightEffects() {
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Bool> { _, action in
          .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    )

    store.send(true)
    store.skipInFlightEffects()
  }

  func testIgnoreReceiveActions_NonExhaustive_ShowInfo() {
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Bool> { _, action in
        action ? .init(value: false) : .none
      }
    )
    store.exhaustivity = .partial

    store.send(true)
  }

  func testIgnoreReceiveActions_NonExhaustive_HideInfo() {
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Bool> { _, action in
        action ? .init(value: false) : .none
      }
    )
    store.exhaustivity = .none

    store.send(true)
  }

  func testIgnoreInFlightEffects_NonExhaustive() {
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Bool> { _, action in
          .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    )
    store.exhaustivity = .partial

    store.send(true)
  }

  func testIgnoreInFlightEffects_NonExhaustive_HideInfo() {
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Bool> { _, action in
          .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    )
    store.exhaustivity = .none

    store.send(true)
  }

  // Confirms that you don't have to assert on all state changes in a non-exhaustive test store.
  func testNonExhaustiveSend() {
    let store = TestStore(
      initialState: Counter.State(),
      reducer: Counter()
    )
    store.exhaustivity = .partial

    // TODO: where's the info?
    store.send(.increment) {
      $0.count = 1
      // Ignoring state change: isEven = false
    }
    store.send(.increment) {
      $0.isEven = true
      // Ignoring state change: count = 2
    }
    store.send(.increment) {
      $0.count = 3
      $0.isEven = false
    }
    XCTExpectFailure {
      _ = store.send(.increment) {
        $0.count = 0
      }
    } issueMatcher: {
      $0.compactDescription == """
        A state change does not match expectation: …

              Counter.State(
            −   count: 0,
            +   count: 4,
                isEven: true
              )

        (Expected: −, Actual: +)
        """
    }
  }

  // Confirms that you can send actions without having received all effect actions in non-exhaustive
  // test stores.
  func testSend_SkipReceivedActions() {
    struct Feature: ReducerProtocol {
      struct State: Equatable {
        var count = 0
        var isLoggedIn = false
      }
      enum Action {
        case decrement
        case increment
        case loggedInResponse(Bool)
      }
      func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .decrement:
          state.count -= 1
          return .none
        case .increment:
          state.count += 1
          return Effect(value: .loggedInResponse(true))
        case let .loggedInResponse(response):
          state.isLoggedIn = response
          return .none
        }
      }
    }
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )
    store.exhaustivity = .partial

    store.send(.increment) {
      $0.count = 1
    }
    // Ignored received action: .loggedInResponse(true)
    store.send(.decrement) {
      $0.count = 0
    }
  }

  // Confirms that with non-exhaustive test stores you can send multiple actions without asserting
  // on any state changes until the very last action.
  func testMultipleSendsWithAssertionOnLast() {
    let store = TestStore(
      initialState: Counter.State(),
      reducer: Counter()
    )
    store.exhaustivity = .partial

    store.send(.increment)
    store.send(.increment)
    store.send(.increment) {
      $0.count = 3
    }
  }

  // Confirms that you don't have to assert on all state changes when receiving an action from an
  // effect in a non-exhaustive test store.
  func testReceive_StateChange() async {
    let store = TestStore(
      initialState: NonExhaustiveReceive.State(),
      reducer: NonExhaustiveReceive()
    )
    store.exhaustivity = .partial

    await store.send(.onAppear)
    await store.receive(.response1(42)) {
      // Ignored state change: count = 1
      $0.int = 42
    }
    await store.receive(.response2("Hello")) {
      // Ignored state change: count = 2
      $0.string = "Hello"
    }
  }

  // Confirms that you can skip receiving certain effect actions in a non-exhaustive test store.
  func testReceive_SkipAction() async {
    let store = TestStore(
      initialState: NonExhaustiveReceive.State(),
      reducer: NonExhaustiveReceive()
    )
    store.exhaustivity = .partial

    await store.send(.onAppear)
    // Ignored received action: .response1(42)
    await store.receive(.response2("Hello")) {
      $0.count = 2
      $0.string = "Hello"
    }
  }
}

struct Counter: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var isEven = true
  }
  enum Action {
    case increment
    case decrement
  }
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .increment:
      state.count += 1
      state.isEven.toggle()
      return .none
    case .decrement:
      state.count -= 1
      state.isEven.toggle()
      return .none
    }
  }
}

struct NonExhaustiveReceive: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var int = 0
    var string = ""
  }
  enum Action: Equatable {
    case onAppear
    case response1(Int)
    case response2(String)
  }
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .onAppear:
      state = State()
      return .merge(
        .init(value: .response1(42)),
        .init(value: .response2("Hello"))
      )
    case let .response1(int):
      state.count += 1
      state.int = int
      return .none
    case let .response2(string):
      state.count += 1
      state.string = string
      return .none
    }
  }
}
