import ComposableArchitecture
import XCTest

@MainActor
final class StoreKindTests: XCTestCase {
  public func testSkipReceivedActions_ShowInfo() {
    let store = TestStore(
      initialState: 0,
      reducer: Reducer<Int, Bool, Void> { _, action, _ in
        action ? .init(value: false) : .none
      },
      environment: ()
    )

    store.kind = .nonExhaustive(showInfo: true)
    store.send(true)
    store.skipReceivedActions()
  }

  public func testSkipInFlightEffects_ShowInfo() {
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Bool> { _, action in
        .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    )

    store.kind = .nonExhaustive(showInfo: true)
    store.send(true)
    store.skipInFlightEffects()
  }

  public func testSkipReceivedActions_HideInfo() {
    let store = TestStore(
      initialState: 0,
      reducer: Reducer<Int, Bool, Void> { _, action, _ in
        action ? .init(value: false) : .none
      },
      environment: ()
    )

    store.kind = .nonExhaustive(showInfo: false)
    store.send(true)
    store.skipReceivedActions()
  }

  public func testSkipReceivedActions_Exhaustive() {
    let store = TestStore(
      initialState: 0,
      reducer: Reducer<Int, Bool, Void> { _, action, _ in
        action ? .init(value: false) : .none
      },
      environment: ()
    )

    store.send(true)
    store.skipReceivedActions()
  }

  public func testSkipInFlightEffects_HideInfo() {
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Bool> { _, action in
        .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    )

    store.kind = .nonExhaustive(showInfo: false)
    store.send(true)
    store.skipInFlightEffects()
  }

  func testSendWithPendingActions() {
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
    store.kind = .nonExhaustive(showInfo: true)

    store.send(.increment) {
      $0.count = 1
    }
    // Ignored received action: .loggedInResponse(true)
    store.send(.decrement) {
      $0.count = 0
    }
  }

  func testNonExhaustiveSend() {
    let store = TestStore(
      initialState: Counter.State(),
      reducer: Counter()
    )
    store.kind = .nonExhaustive(showInfo: true)

    store.send(.increment) {
      $0.count = 1
    }
    store.send(.decrement) {
      $0.count = 0
    }
    store.send(.increment) {
      $0.isEven = false
    }
    store.send(.decrement) {
      $0.isEven = true
    }
    store.send(.increment) {
      $0.count = 1
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
            +   count: 2,
                isEven: true
              )

        (Expected: −, Actual: +)
        """
    }
  }

  func testMultipleSendsWithAssertionOnLast() {
    let store = TestStore(
      initialState: Counter.State(),
      reducer: Counter()
    )
    store.kind = .nonExhaustive(showInfo: true)

    store.send(.increment)
    store.send(.increment)
    store.send(.increment) {
      $0.count = 3
    }
  }

  func testNonExhaustiveReceive() async {
    struct State: Equatable {
      var int = 0
      var string = ""
    }
    enum Action: Equatable {
      case onAppear
      case response1(Int)
      case response2(String)
    }
    let featureReducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .onAppear:
        state = State()
        return .merge(
          .init(value: .response1(42)),
          .init(value: .response2("Hello"))
        )
      case let .response1(int):
        state.int = int
        return .none
      case let .response2(string):
        state.string = string
        return .none
      }
    }

    let store = TestStore(
      initialState: State(),
      reducer: featureReducer,
      environment: ()
    )
    store.kind = .nonExhaustive(showInfo: true)

    await store.send(.onAppear)
    await store.receive(.response2("Hello")) {
      $0.string = "Hello"
    }

    await store.send(.onAppear)
    await store.receive(.response1(42)) {
      $0.int = 42
    }

    await store.send(.onAppear)
    // TODO:
    //    store.receive(/Action.response2) {
    //      $0.int = 42
    //    }

    XCTExpectFailure {
      store.receive(.response1(1))
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
