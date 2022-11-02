#if DEBUG
  import ComposableArchitecture
  import XCTest
 
  @MainActor
  final class TestStoreNonExhaustiveTests: XCTestCase {
    func testSkipReceivedActions_NonStrict() async {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { state, action in
          if action {
            state += 1
            return .init(value: false)
          } else {
            state += 1
            return .none
          }
        }
      )

      await store.send(true) { $0 = 1 }
      XCTAssertEqual(store.state, 1)
      await store.skipReceivedActions(strict: false)
      XCTAssertEqual(store.state, 2)
    }

    func testSkipReceivedActions_Strict() async {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { state, action in
          if action {
            state += 1
            return .init(value: false)
          } else {
            state += 1
            return .none
          }
        }
      )

      await store.send(true) { $0 = 1 }
      XCTAssertEqual(store.state, 1)
      await store.receive(false) { $0 = 2 }
      XCTAssertEqual(store.state, 2)
      XCTExpectFailure {
        $0.compactDescription == "There were no received actions to skip."
      }
      await store.skipReceivedActions(strict: true)
    }

    func testSkipReceivedActions_NonExhaustive() async {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { state, action in
          if action {
            state += 1
            return .init(value: false)
          } else {
            state += 1
            return .none
          }
        }
      )
      store.exhaustivity = .off

      await store.send(true) { $0 = 1 }
      XCTAssertEqual(store.state, 1)
      await store.skipReceivedActions(strict: false)
      XCTAssertEqual(store.state, 2)
    }

    func testSkipReceivedActions_PartialExhaustive() async {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { state, action in
          if action {
            state += 1
            return .init(value: false)
          } else {
            state += 1
            return .none
          }
        }
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(true) { $0 = 1 }
      XCTAssertEqual(store.state, 1)
      await store.skipReceivedActions(strict: false)
      XCTAssertEqual(store.state, 2)
    }

    func testCancelInFlightEffects_NonStrict() async {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { _, action in
          .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
        }
      )

      await store.send(true)
      await store.skipInFlightEffects(strict: false)
    }

    func testCancelInFlightEffects_Strict() async {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { _, action in
          .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC / 4) }
        }
      )

      let task = await store.send(true)
      await task.finish(timeout: NSEC_PER_SEC / 2)
      XCTExpectFailure {
        $0.compactDescription == "There were no in-flight effects to skip."
      }
      await store.skipInFlightEffects(strict: true)
    }

    func testCancelInFlightEffects_NonExhaustive() async {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { _, action in
          .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
        }
      )
      store.exhaustivity = .off

      await store.send(true)
      await store.skipInFlightEffects(strict: false)
    }

    func testCancelInFlightEffects_PartialExhaustive() async {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { _, action in
          .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
        }
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(true)
      await store.skipInFlightEffects(strict: false)
    }

    // Confirms that you don't have to receive all actions before the test completes.
    func testIgnoreReceiveActions_PartialExhaustive() {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { _, action in
          action ? .init(value: false) : .none
        }
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      store.send(true)
    }

    // Confirms that you don't have to receive all actions before the test completes.
    func testIgnoreReceiveActions_NonExhaustive() {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { _, action in
          action ? .init(value: false) : .none
        }
      )
      store.exhaustivity = .off

      store.send(true)
    }

    // Confirms that all effects do not need to complete before the test completes.
    func testIgnoreInFlightEffects_PartialExhaustive() {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { _, action in
          .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
        }
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      store.send(true)
    }

    // Confirms that all effects do not need to complete before the test completes.
    func testIgnoreInFlightEffects_NonExhaustive() {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Bool> { _, action in
          .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
        }
      )
      store.exhaustivity = .off

      store.send(true)
    }

    // Confirms that you don't have to assert on all state changes in a non-exhaustive test store.
    func testNonExhaustiveSend_PartialExhaustive() {
      let store = TestStore(
        initialState: Counter.State(),
        reducer: Counter()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

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
    }

    func testNonExhaustiveSend_PartialExhaustive_Prefix() {
      let store = TestStore(
        initialState: Counter.State(),
        reducer: Counter()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)
 
      store.send(.increment) {
        $0.count = 1
        // Ignoring state change: isEven = false
      }
    }

    // Confirms that you don't have to assert on all state changes in a non-exhaustive test store,
    // *but* if you make an incorrect mutation you will still get a failure.
    func testNonExhaustiveSend_PartialExhaustive_BadAssertion() {
      let store = TestStore(
        initialState: Counter.State(),
        reducer: Counter()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      #if DEBUG
        XCTExpectFailure {
          _ = store.send(.increment) {
            $0.count = 0
          }
        } issueMatcher: {
          $0.compactDescription == """
            A state change does not match expectation: …

                  Counter.State(
                −   count: 0,
                +   count: 1,
                    isEven: false
                  )

            (Expected: −, Actual: +)
            """
        }
      #endif
    }

    // Confirms that you don't have to assert on all state changes in a non-exhaustive test store,
    // *and* that informational boxes of what was not asserted on is not shown.
    func testNonExhaustiveSend_NonExhaustive() {
      let store = TestStore(
        initialState: Counter.State(),
        reducer: Counter()
      )
      store.exhaustivity = .off

      store.send(.increment) {
        $0.count = 1
        // Ignoring state change: isEven = false
      }
    }

    // Confirms that you can send actions without having received all effect actions in
    // non-exhaustive test stores.
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
      store.exhaustivity = .off(showSkippedAssertions: true)

      store.send(.increment) {
        $0.count = 1
      }
      // Ignored received action: .loggedInResponse(true)
      store.send(.decrement) {
        $0.count = 0
        // Ignored state change: isLoggedIn = true
      }
    }

    // Confirms that if you receive an action in a non-exhaustive test store with a bad assertion
    // you will still get a failure.
    func testSend_SkipReceivedActions_BadAssertion() {
      struct Feature: ReducerProtocol {
        struct State: Equatable {
          var count = 0
          var isLoggedIn = false
        }
        enum Action: Equatable {
          case increment
          case loggedInResponse(Bool)
        }
        func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
          switch action {
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
      store.exhaustivity = .off(showSkippedAssertions: true)

      store.send(.increment) {
        $0.count = 1
      }
      XCTExpectFailure {
        store.receive(.loggedInResponse(true)) {
          $0.count = 2
          $0.isLoggedIn = true
        }
      } issueMatcher: {
        $0.compactDescription == """
          A state change does not match expectation: …

                TestStoreNonExhaustiveTests.Feature.State(
              −   count: 2,
              +   count: 1,
                  isLoggedIn: true
                )

          (Expected: −, Actual: +)
          """
      }
    }

    // Confirms that with non-exhaustive test stores you can send multiple actions without asserting
    // on any state changes until the very last action.
    func testMultipleSendsWithAssertionOnLast() {
      let store = TestStore(
        initialState: Counter.State(),
        reducer: Counter()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      store.send(.increment)
      XCTAssertEqual(store.state, Counter.State(count: 1, isEven: false))

      store.send(.increment)
      XCTAssertEqual(store.state, Counter.State(count: 2, isEven: true))

      store.send(.increment) {
        $0.count = 3
      }
      XCTAssertEqual(store.state, Counter.State(count: 3, isEven: false))
    }

    // Confirms that you don't have to assert on all state changes when receiving an action from an
    // effect in a non-exhaustive test store.
    func testReceive_StateChange() async {
      let store = TestStore(
        initialState: NonExhaustiveReceive.State(),
        reducer: NonExhaustiveReceive()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(.onAppear)
      XCTAssertEqual(store.state, NonExhaustiveReceive.State(count: 0, int: 0, string: ""))

      await store.receive(.response1(42)) {
        // Ignored state change: count = 1
        $0.int = 42
      }
      XCTAssertEqual(store.state, NonExhaustiveReceive.State(count: 1, int: 42, string: ""))

      await store.receive(.response2("Hello")) {
        // Ignored state change: count = 2
        $0.string = "Hello"
      }
      XCTAssertEqual(store.state, NonExhaustiveReceive.State(count: 2, int: 42, string: "Hello"))
    }

    // Confirms that you can skip receiving certain effect actions in a non-exhaustive test store.
    func testReceive_SkipAction() async {
      let store = TestStore(
        initialState: NonExhaustiveReceive.State(),
        reducer: NonExhaustiveReceive()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(.onAppear)
      XCTAssertEqual(store.state, NonExhaustiveReceive.State(count: 0, int: 0, string: ""))

      // Ignored received action: .response1(42)

      await store.receive(.response2("Hello")) {
        $0.count = 2
        $0.string = "Hello"
      }
      XCTAssertEqual(store.state, NonExhaustiveReceive.State(count: 2, int: 42, string: "Hello"))
    }

    // Confirms that you are allowed to send actions without having received all actions queued
    // from effects.
    func testSendWithUnreceivedAction() async {
      let store = TestStore(
        initialState: NonExhaustiveReceive.State(),
        reducer: NonExhaustiveReceive()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(.onAppear)
      // Ignored received action: .response1(42)
      // Ignored received action: .response2("Hello")

      await store.send(.onAppear)
      // Ignored received action: .response1(42)
      // Ignored received action: .response2("Hello")
    }

    // Confirms that when you send an action the test store skips any unreceived actions
    // automatically.
    func testSendWithUnreceivedActions_SkipsActions() async {
      struct Feature: ReducerProtocol {
        enum Action: Equatable {
          case tap
          case response(Int)
        }
        func reduce(into state: inout Int, action: Action) -> Effect<Action, Never> {
          switch action {
          case .tap:
            state += 1
            return .task { [state] in .response(state + 42) }
          case let .response(number):
            state = number
            return .none
          }
        }
      }

      let store = TestStore(
        initialState: 0,
        reducer: Feature()
      )
      store.exhaustivity = .off

      await store.send(.tap)
      XCTAssertEqual(store.state, 1)

      // Ignored received action: .response(43)
      await store.send(.tap)
      XCTAssertEqual(store.state, 44)

      await store.skipReceivedActions()
      XCTAssertEqual(store.state, 86)
    }

    func testPartialExhaustivityPrefix() async {
      let testScheduler = DispatchQueue.test
      enum Action {
        case buttonTapped
        case response(Int)
      }
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Action> { state, action in
          switch action {
          case .buttonTapped:
            state += 1
            return .run { send in
              await send(.response(42))
              try await testScheduler.sleep(for: .seconds(1))
              await send(.response(1729))
            }
          case let .response(number):
            state = number
            return .none
          }
        }
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(.buttonTapped)
      // Ignored state mutation: state = 1
      // Ignored received action: .response(42)
      await testScheduler.advance(by: .milliseconds(500))
      await store.send(.buttonTapped) {
        $0 = 43
      }

      await testScheduler.advance(by: .milliseconds(500))
      await store.skipInFlightEffects()
      await store.skipReceivedActions()
      // Ignored received action: .response(42)
      // Ignored received action: .response(1729)
      // Ignore in-flight effect
    }

    func testCasePathReceive_PartialExhaustive() async {
      let store = TestStore(
        initialState: NonExhaustiveReceive.State(),
        reducer: NonExhaustiveReceive()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(.onAppear)
      await store.receive(/NonExhaustiveReceive.Action.response1) {
        $0.int = 42
      }
      await store.receive(/NonExhaustiveReceive.Action.response2) {
        $0.string = "Hello"
      }
    }

    func testCasePathReceive_NonExhaustive() async {
      let store = TestStore(
        initialState: NonExhaustiveReceive.State(),
        reducer: NonExhaustiveReceive()
      )
      store.exhaustivity = .off

      await store.send(.onAppear)
      await store.receive(/NonExhaustiveReceive.Action.response1) {
        $0.int = 42
      }
      await store.receive(/NonExhaustiveReceive.Action.response2) {
        $0.string = "Hello"
      }
    }

    func testCasePathReceive_Exhaustive() async {
      let store = TestStore(
        initialState: NonExhaustiveReceive.State(),
        reducer: NonExhaustiveReceive()
      )

      await store.send(.onAppear)
      await store.receive(/NonExhaustiveReceive.Action.response1) {
        $0.count = 1
        $0.int = 42
      }
      await store.receive(/NonExhaustiveReceive.Action.response2) {
        $0.count = 2
        $0.string = "Hello"
      }
    }

    func testCasePathReceive_SkipReceivedAction() async {
      let store = TestStore(
        initialState: NonExhaustiveReceive.State(),
        reducer: NonExhaustiveReceive()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(.onAppear)
      await store.receive(/NonExhaustiveReceive.Action.response2) {
        $0.string = "Hello"
      }
    }

    func testCasePathReceive_WrongAction() async {
      let store = TestStore(
        initialState: NonExhaustiveReceive.State(),
        reducer: NonExhaustiveReceive()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(.onAppear)

      XCTExpectFailure {
        $0.compactDescription == """
          Expected to receive a matching action, but didn't get one.
          """
      }

      await store.receive(/NonExhaustiveReceive.Action.onAppear)
      await store.receive(/NonExhaustiveReceive.Action.response1)
      await store.receive(/NonExhaustiveReceive.Action.response2)
    }

    func testCasePathReceive_ReceivedExtraAction() async {
      let store = TestStore(
        initialState: NonExhaustiveReceive.State(),
        reducer: NonExhaustiveReceive()
      )
      store.exhaustivity = .off(showSkippedAssertions: true)

      await store.send(.onAppear)
      await store.receive(/NonExhaustiveReceive.Action.response2)

      XCTExpectFailure {
        $0.compactDescription == """
          Expected to receive an action, but received none.
          """
      }

      await store.receive(/NonExhaustiveReceive.Action.response2)
    }

    // This example comes from Krzysztof Zabłocki's blog post:
    // https://www.merowing.info/exhaustive-testing-in-tca/
    func testKrzysztofExample1() {
      let store = TestStore(
        initialState: KrzysztofExample.State(),
        reducer: KrzysztofExample()
      )
      store.exhaustivity = .off

      store.send(.changeIdentity(name: "Marek", surname: "Ignored")) {
        $0.name = "Marek"
      }
    }

    // This example comes from Krzysztof Zabłocki's blog post:
    // https://www.merowing.info/exhaustive-testing-in-tca/
    func testKrzysztofExample2() {
      let store = TestStore(
        initialState: KrzysztofExample.State(),
        reducer: KrzysztofExample()
      )
      store.exhaustivity = .off

      store.send(.changeIdentity(name: "Adam", surname: "Stern"))
      store.send(.changeIdentity(name: "Piotr", surname: "Galiszewski"))
      store.send(.changeIdentity(name: "Merowing", surname: "Info")) {
        $0.name = "Merowing"
        $0.surname = "Info"
      }
    }

    // This example comes from Krzysztof Zabłocki's blog post:
    // https://www.merowing.info/exhaustive-testing-in-tca/
    func testKrzysztofExample3() {
      let mainQueue = DispatchQueue.test

      let store = TestStore(
        initialState: KrzysztofExample.State(),
        reducer: KrzysztofExample()
      )
      store.exhaustivity = .off
      store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()

      store.send(.advanceAgeAndMoodAfterDelay)
      mainQueue.advance(by: 1)
      store.receive(.changeAge(34)) {
        $0.age = 34
      }
      XCTAssertEqual(store.state.age, 34)
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

  // This example comes from Krzysztof Zabłocki's blog post:
  // https://www.merowing.info/exhaustive-testing-in-tca/
  struct KrzysztofExample: ReducerProtocol {
    struct State: Equatable {
      var name: String = "Krzysztof"
      var surname: String = "Zabłocki"
      var age: Int = 33
      var mood: Int = 0
    }
    enum Action: Equatable {
      case changeIdentity(name: String, surname: String)
      case changeAge(Int)
      case changeMood(Int)
      case advanceAgeAndMoodAfterDelay
    }

    @Dependency(\.mainQueue) var mainQueue

    func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
      switch action {
      case let .changeIdentity(name, surname):
        state.name = name
        state.surname = surname
        return .none

      case .advanceAgeAndMoodAfterDelay:
        return .merge(
          .init(value: .changeAge(state.age + 1)),
          .init(value: .changeMood(state.mood + 1))
        )
        .delay(for: 1, scheduler: self.mainQueue)
        .eraseToEffect()

      case let .changeAge(age):
        state.age = age
        return .none
      case let .changeMood(mood):
        state.mood = mood
        return .none
      }
    }
  }
#endif
