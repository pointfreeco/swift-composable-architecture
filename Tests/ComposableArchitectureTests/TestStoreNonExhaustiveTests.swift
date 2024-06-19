import ComposableArchitecture
import XCTest

final class TestStoreNonExhaustiveTests: BaseTCATestCase {
  @MainActor
  func testSkipReceivedActions_NonStrict() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { state, action in
        if action {
          state += 1
          return .send(false)
        } else {
          state += 1
          return .none
        }
      }
    }

    await store.send(true) { $0 = 1 }
    XCTAssertEqual(store.state, 1)
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state, 2)
  }

  @MainActor
  func testSkipReceivedActions_Strict() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { state, action in
        if action {
          state += 1
          return .send(false)
        } else {
          state += 1
          return .none
        }
      }
    }

    await store.send(true) { $0 = 1 }
    XCTAssertEqual(store.state, 1)
    await store.receive(false) { $0 = 2 }
    XCTAssertEqual(store.state, 2)
    XCTExpectFailure {
      $0.compactDescription == "There were no received actions to skip."
    }
    await store.skipReceivedActions(strict: true)
  }

  @MainActor
  func testSkipReceivedActions_NonExhaustive() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { state, action in
        if action {
          state += 1
          return .send(false)
        } else {
          state += 1
          return .none
        }
      }
    }
    store.exhaustivity = .off

    await store.send(true) { $0 = 1 }
    XCTAssertEqual(store.state, 1)
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state, 2)
  }

  @MainActor
  func testSkipReceivedActions_PartialExhaustive() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { state, action in
        if action {
          state += 1
          return .send(false)
        } else {
          state += 1
          return .none
        }
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(true) { $0 = 1 }
    XCTAssertEqual(store.state, 1)
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state, 2)
  }

  @MainActor
  func testCancelInFlightEffects_NonStrict() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { _, action in
        .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    }

    await store.send(true)
    await store.skipInFlightEffects(strict: false)
  }

  @MainActor
  func testCancelInFlightEffects_Strict() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { _, action in
        .run { _ in }
      }
    }

    let task = await store.send(true)
    await task.finish(timeout: NSEC_PER_SEC / 2)
    XCTExpectFailure {
      $0.compactDescription == "There were no in-flight effects to skip."
    }
    await store.skipInFlightEffects(strict: true)
  }

  @MainActor
  func testCancelInFlightEffects_NonExhaustive() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { _, action in
        .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    }
    store.exhaustivity = .off

    await store.send(true)
    await store.skipInFlightEffects(strict: false)
  }

  @MainActor
  func testCancelInFlightEffects_PartialExhaustive() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { _, action in
        .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(true)
    await store.skipInFlightEffects(strict: false)
  }

  // Confirms that you don't have to receive all actions before the test completes.
  @MainActor
  func testIgnoreReceiveActions_PartialExhaustive() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { _, action in
        action ? .send(false) : .none
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(true)
  }

  // Confirms that you don't have to receive all actions before the test completes.
  @MainActor
  func testIgnoreReceiveActions_NonExhaustive() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { _, action in
        action ? .send(false) : .none
      }
    }
    store.exhaustivity = .off

    await store.send(true)
  }

  // Confirms that all effects do not need to complete before the test completes.
  @MainActor
  func testIgnoreInFlightEffects_PartialExhaustive() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { _, action in
        .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(true)
  }

  // Confirms that all effects do not need to complete before the test completes.
  @MainActor
  func testIgnoreInFlightEffects_NonExhaustive() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { _, action in
        .run { _ in try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
      }
    }
    store.exhaustivity = .off

    await store.send(true)
  }

  // Confirms that you don't have to assert on all state changes in a non-exhaustive test store.
  @MainActor
  func testNonExhaustiveSend_PartialExhaustive() async {
    let store = TestStore(initialState: Counter.State()) {
      Counter()
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.increment) {
      $0.count = 1
      // Ignoring state change: isEven = false
    }
    await store.send(.increment) {
      $0.isEven = true
      // Ignoring state change: count = 2
    }
    await store.send(.increment) {
      $0.count = 3
      $0.isEven = false
    }
  }

  @MainActor
  func testNonExhaustiveSend_PartialExhaustive_Prefix() async {
    let store = TestStore(initialState: Counter.State()) {
      Counter()
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.increment) {
      $0.count = 1
      // Ignoring state change: isEven = false
    }
  }

  // Confirms that you don't have to assert on all state changes in a non-exhaustive test store,
  // *but* if you make an incorrect mutation you will still get a failure.
  @MainActor
  func testNonExhaustiveSend_PartialExhaustive_BadAssertion() async {
    let store = TestStore(initialState: Counter.State()) {
      Counter()
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    XCTExpectFailure {
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
    await store.send(.increment) {
      $0.count = 0
    }
  }

  // Confirms that you don't have to assert on all state changes in a non-exhaustive test store,
  // *and* that informational boxes of what was not asserted on is not shown.
  @MainActor
  func testNonExhaustiveSend_NonExhaustive() async {
    let store = TestStore(initialState: Counter.State()) {
      Counter()
    }
    store.exhaustivity = .off

    await store.send(.increment) {
      $0.count = 1
      // Ignoring state change: isEven = false
    }
  }

  // Confirms that you can send actions without having received all effect actions in
  // non-exhaustive test stores.
  @MainActor
  func testSend_SkipReceivedActions() async {
    struct State: Equatable {
      var count = 0
      var isLoggedIn = false
    }
    enum Action {
      case decrement
      case increment
      case loggedInResponse(Bool)
    }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .decrement:
          state.count -= 1
          return .none
        case .increment:
          state.count += 1
          return .send(.loggedInResponse(true))
        case let .loggedInResponse(response):
          state.isLoggedIn = response
          return .none
        }
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.increment) {
      $0.count = 1
    }
    // Ignored received action: .loggedInResponse(true)
    await store.send(.decrement) {
      $0.count = 0
      // Ignored state change: isLoggedIn = true
    }
  }

  // Confirms that if you receive an action in a non-exhaustive test store with a bad assertion
  // you will still get a failure.
  @MainActor
  func testSend_SkipReceivedActions_BadAssertion() async {
    struct State: Equatable {
      var count = 0
      var isLoggedIn = false
    }
    enum Action: Equatable {
      case increment
      case loggedInResponse(Bool)
    }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .increment:
          state.count += 1
          return .send(.loggedInResponse(true))
        case let .loggedInResponse(response):
          state.isLoggedIn = response
          return .none
        }
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.increment) {
      $0.count = 1
    }
    XCTExpectFailure {
      $0.compactDescription == """
        A state change does not match expectation: …

              TestStoreNonExhaustiveTests.State(
            −   count: 2,
            +   count: 1,
                isLoggedIn: true
              )

        (Expected: −, Actual: +)
        """
    }
    await store.receive(.loggedInResponse(true)) {
      $0.count = 2
      $0.isLoggedIn = true
    }
  }

  // Confirms that with non-exhaustive test stores you can send multiple actions without asserting
  // on any state changes until the very last action.
  @MainActor
  func testMultipleSendsWithAssertionOnLast() async {
    let store = TestStore(initialState: Counter.State()) {
      Counter()
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.increment)
    XCTAssertEqual(store.state, Counter.State(count: 1, isEven: false))

    await store.send(.increment)
    XCTAssertEqual(store.state, Counter.State(count: 2, isEven: true))

    await store.send(.increment) {
      $0.count = 3
    }
    XCTAssertEqual(store.state, Counter.State(count: 3, isEven: false))
  }

  // Confirms that you don't have to assert on all state changes when receiving an action from an
  // effect in a non-exhaustive test store.
  @MainActor
  func testReceive_StateChange() async {
    let store = TestStore(initialState: NonExhaustiveReceive.State()) {
      NonExhaustiveReceive()
    }
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
  @MainActor
  func testReceive_SkipAction() async {
    let store = TestStore(initialState: NonExhaustiveReceive.State()) {
      NonExhaustiveReceive()
    }
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
  @MainActor
  func testSendWithUnreceivedAction() async {
    let store = TestStore(initialState: NonExhaustiveReceive.State()) {
      NonExhaustiveReceive()
    }
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
  @MainActor
  func testSendWithUnreceivedActions_SkipsActions() async {
    enum Action: Equatable {
      case tap
      case response(Int)
    }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .tap:
          state += 1
          return .run { [state] send in await send(.response(state + 42)) }
        case let .response(number):
          state = number
          return .none
        }
      }
    }
    store.exhaustivity = .off

    await store.send(.tap)
    XCTAssertEqual(store.state, 1)

    // Ignored received action: .response(43)
    await store.send(.tap)
    XCTAssertEqual(store.state, 44)

    await store.skipReceivedActions()
    XCTAssertEqual(store.state, 86)
  }

  @MainActor
  func testPartialExhaustivityPrefix() async {
    let testScheduler = DispatchQueue.test
    enum Action {
      case buttonTapped
      case response(Int)
    }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
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
    }
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

  @MainActor
  func testCasePathReceive_PartialExhaustive() async {
    let store = TestStore(initialState: NonExhaustiveReceive.State()) {
      NonExhaustiveReceive()
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.onAppear)
    await store.receive(\.response1) {
      $0.int = 42
    }
    await store.receive(\.response2) {
      $0.string = "Hello"
    }
  }

  @MainActor
  func testCasePathReceive_NonExhaustive() async {
    let store = TestStore(initialState: NonExhaustiveReceive.State()) {
      NonExhaustiveReceive()
    }
    store.exhaustivity = .off

    await store.send(.onAppear)
    await store.receive(\.response1) {
      $0.int = 42
    }
    await store.receive(\.response2) {
      $0.string = "Hello"
    }
  }

  @MainActor
  func testCasePathReceive_Exhaustive() async {
    let store = TestStore(initialState: NonExhaustiveReceive.State()) {
      NonExhaustiveReceive()
    }

    await store.send(.onAppear)
    await store.receive(\.response1) {
      $0.count = 1
      $0.int = 42
    }
    await store.receive(\.response2) {
      $0.count = 2
      $0.string = "Hello"
    }
  }

  @MainActor
  func testCasePathReceive_Exhaustive_NonEquatable() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, NonEquatableAction> { state, action in
        switch action {
        case .tap:
          return .send(.response(NonEquatable()))
        case .response:
          return .none
        }
      }
    }

    await store.send(.tap)
    await store.receive(\.response)
  }

  @MainActor
  func testPredicateReceive_Exhaustive_NonEquatable() async {
    struct NonEquatable {}
    enum Action {
      case tap
      case response(NonEquatable)
    }

    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .tap:
          return .send(.response(NonEquatable()))
        case .response:
          return .none
        }
      }
    }

    await store.send(.tap)
    await store.receive { if case .response = $0 { return true } else { return false } }
  }

  @MainActor
  func testCasePathReceive_SkipReceivedAction() async {
    let store = TestStore(initialState: NonExhaustiveReceive.State()) {
      NonExhaustiveReceive()
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.onAppear)
    await store.receive(\.response2) {
      $0.string = "Hello"
    }
  }

  @MainActor
  func testCasePathReceive_WrongAction() async {
    let store = TestStore(initialState: NonExhaustiveReceive.State()) {
      NonExhaustiveReceive()
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.onAppear)

    XCTExpectFailure {
      $0.compactDescription == """
        Expected to receive an action matching case path, but didn't get one.
        """
    }

    await store.receive(\.onAppear)
    await store.receive(\.response1)
    await store.receive(\.response2)
  }

  @MainActor
  func testCasePathReceive_ReceivedExtraAction() async {
    let store = TestStore(initialState: NonExhaustiveReceive.State()) {
      NonExhaustiveReceive()
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.onAppear)
    await store.receive(\.response2)

    XCTExpectFailure {
      $0.compactDescription == """
        Expected to receive an action matching case path, but didn't get one.
        """
    }

    await store.receive(\.response2)
  }

  @MainActor
  func testXCTModifyExhaustive() async {
    struct State: Equatable {
      var child: Int? = 0
      var count = 0
    }
    enum Action: Equatable { case tap, response }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tap:
          state.count += 1
          return .send(.response)
        case .response:
          state.count += 1
          return .none
        }
      }
    }

    await store.send(.tap) { state in
      state.count = 1
      XCTExpectFailure {
        XCTModify(&state.child) { _ in }
      } issueMatcher: {
        $0.compactDescription == """
          XCTModify failed: expected "Int" value to be modified but it was unchanged.
          """
      }
    }
    await store.receive(.response) { state in
      state.count = 2
      XCTExpectFailure {
        XCTModify(&state.child) { _ in }
      } issueMatcher: {
        $0.compactDescription == """
          XCTModify failed: expected "Int" value to be modified but it was unchanged.
          """
      }
    }
  }

  @MainActor
  func testXCTModifyNonExhaustive() async {
    enum Action { case tap, response }
    let store = TestStore(initialState: Optional(1)) {
      Reduce<Int?, Action> { state, action in
        switch action {
        case .tap:
          return .send(.response)
        case .response:
          return .none
        }
      }
    }
    store.exhaustivity = .off

    await store.send(.tap) {
      XCTModify(&$0) { _ in }
    }
    await store.receive(.response) {
      XCTModify(&$0) { _ in }
    }
  }

  @MainActor
  func testReceiveNonExhaustiveWithTimeout() async {
    struct State: Equatable {}
    enum Action: Equatable { case tap, response1, response2 }

    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tap:
          return .run { send in
            try await Task.sleep(nanoseconds: 10_000_000)
            await send(.response1)
            try await Task.sleep(nanoseconds: 10_000_000)
            await send(.response2)
          }
        case .response1, .response2:
          return .none
        }
      }
    }
    store.exhaustivity = .off

    await store.send(.tap)
    await store.receive(.response2, timeout: 1_000_000_000)
  }

  @MainActor
  func testReceiveNonExhaustiveWithTimeoutMultipleNonMatching() async {
    struct State: Equatable {}
    enum Action: Equatable { case tap, response1, response2 }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tap:
          return .run { send in
            try await Task.sleep(nanoseconds: 10_000_000)
            await send(.response1)
            try await Task.sleep(nanoseconds: 10_000_000)
            await send(.response1)
          }
        case .response1:
          return .none
        case .response2:
          return .none
        }
      }
    }
    store.exhaustivity = .off

    await store.send(.tap)
    XCTExpectFailure { issue in
      issue.compactDescription.contains(
        """
        Expected to receive a matching action, but received none after 1.0 seconds.
        """)
        || (issue.compactDescription.contains(
          "Expected to receive the following action, but didn't")
          && issue.compactDescription.contains("Action.response2"))
    }
    await store.receive(.response2, timeout: 1_000_000_000)
  }

  @MainActor
  func testReceiveNonExhaustiveWithTimeoutMultipleMatching() async {
    struct State: Equatable {}
    enum Action: Equatable { case tap, response1, response2 }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tap:
          return .run { send in
            try await Task.sleep(nanoseconds: 10_000_000)
            await send(.response2)
            try await Task.sleep(nanoseconds: 10_000_000)
            await send(.response2)
          }
        case .response1, .response2:
          return .none
        }
      }
    }
    store.exhaustivity = .off

    await store.send(.tap)
    await store.receive(.response2, timeout: 1_000_000_000)
    await store.receive(.response2, timeout: 1_000_000_000)
  }

  @MainActor
  func testNonExhaustive_ShowSkippedAssertions_ExpectedStateToChange() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Void> { _, _ in .none }
    }
    store.exhaustivity = .off(showSkippedAssertions: true)
    await store.send(()) { $0 = 0 }
    store.assert { $0 = 0 }
  }

  // This example comes from Krzysztof Zabłocki's blog post:
  // https://www.merowing.info/exhaustive-testing-in-tca/
  @MainActor
  func testKrzysztofExample1() async {
    let store = TestStore(initialState: KrzysztofExample.State()) {
      KrzysztofExample()
    }
    store.exhaustivity = .off

    await store.send(.changeIdentity(name: "Marek", surname: "Ignored")) {
      $0.name = "Marek"
    }
  }

  // This example comes from Krzysztof Zabłocki's blog post:
  // https://www.merowing.info/exhaustive-testing-in-tca/
  @MainActor
  func testKrzysztofExample2() async {
    let store = TestStore(initialState: KrzysztofExample.State()) {
      KrzysztofExample()
    }
    store.exhaustivity = .off

    await store.send(.changeIdentity(name: "Adam", surname: "Stern"))
    await store.send(.changeIdentity(name: "Piotr", surname: "Galiszewski"))
    await store.send(.changeIdentity(name: "Merowing", surname: "Info")) {
      $0.name = "Merowing"
      $0.surname = "Info"
    }
  }

  // This example comes from Krzysztof Zabłocki's blog post:
  // https://www.merowing.info/exhaustive-testing-in-tca/
  @MainActor
  func testKrzysztofExample3() async {
    let mainQueue = DispatchQueue.test

    let store = TestStore(initialState: KrzysztofExample.State()) {
      KrzysztofExample()
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }
    store.exhaustivity = .off

    await store.send(.advanceAgeAndMoodAfterDelay)
    await mainQueue.advance(by: 1)
    await store.receive(.changeAge(34)) {
      $0.age = 34
    }
    XCTAssertEqual(store.state.age, 34)
  }

  @MainActor
  func testEffectfulAssertion_NonExhaustiveTestStore_ShowSkippedAssertions() async {
    struct Model: Equatable {
      let id: UUID
      init() {
        @Dependency(\.uuid) var uuid
        self.id = uuid()
      }
    }
    struct State: Equatable {
      var values: [Model] = []
    }
    enum Action {
      case addButtonTapped
    }

    XCTTODO(
      """
      This test should pass once we have the concept of "copyable" dependencies.
      """
    )

    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .addButtonTapped:
          state.values.append(Model())
          return .none
        }
      }
    } withDependencies: {
      $0.uuid = .incrementing
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.addButtonTapped) {
      $0.values.insert(Model(), at: 0)
    }
    await store.send(.addButtonTapped) {
      $0.values.insert(Model(), at: 1)
    }
  }
}

@Reducer
struct Counter {
  struct State: Equatable {
    var count = 0
    var isEven = true
  }
  enum Action {
    case increment
    case decrement
  }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
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
}

@Reducer
struct NonExhaustiveReceive {
  struct State: Equatable {
    var count = 0
    var int = 0
    var string = ""
  }
  @dynamicMemberLookup
  enum Action: Equatable {
    case onAppear
    case response1(Int)
    case response2(String)
  }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state = State()
        return .merge(
          .send(.response1(42)),
          .send(.response2("Hello"))
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
}

// This example comes from Krzysztof Zabłocki's blog post:
// https://www.merowing.info/exhaustive-testing-in-tca/
@Reducer
struct KrzysztofExample {
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

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .changeIdentity(name, surname):
        state.name = name
        state.surname = surname
        return .none

      case .advanceAgeAndMoodAfterDelay:
        return .run { [state] send in
          try await self.mainQueue.sleep(for: .seconds(1))
          async let changeAge: () = send(.changeAge(state.age + 1))
          async let changeMood: () = send(.changeMood(state.mood + 1))
          _ = await (changeAge, changeMood)
        }

      case let .changeAge(age):
        state.age = age
        return .none
      case let .changeMood(mood):
        state.mood = mood
        return .none
      }
    }
  }
}

private struct NonEquatable {}
@CasePathable
@dynamicMemberLookup
private enum NonEquatableAction {
  case tap
  case response(NonEquatable)
}
