import ComposableArchitecture
import XCTest

@available(*, deprecated, message: "TODO: Update to use case pathable syntax with Swift 5.9")
final class IfCaseLetReducerTests: BaseTCATestCase {
  @MainActor
  func testChildAction() async {
    struct SomeError: Error, Equatable {}

    let store = TestStore(initialState: Result.success(0)) {
      Reduce<Result<Int, SomeError>, Result<Int, SomeError>> { state, action in
        .none
      }
      .ifCaseLet(\.success, action: \.success) {
        Reduce { state, action in
          state = action
          return state < 0 ? .run { await $0(0) } : .none
        }
      }
    }

    await store.send(.success(1)) {
      $0 = .success(1)
    }
    await store.send(.failure(SomeError()))
    await store.send(.success(-1)) {
      $0 = .success(-1)
    }
    await store.receive(.success(0)) {
      $0 = .success(0)
    }
  }

  @MainActor
  func testNilChild() async {
    struct SomeError: Error, Equatable {}

    let store = TestStore(initialState: Result.failure(SomeError())) {
      EmptyReducer<Result<Int, SomeError>, Result<Int, SomeError>>()
        .ifCaseLet(\.success, action: \.success) {}
    }

    XCTExpectFailure {
      $0.compactDescription == """
        An "ifCaseLet" at "\(#fileID):\(#line - 5)" received a child action when child state was \
        set to a different case. …

          Action:
            Result.success(1)
          State:
            Result.failure(IfCaseLetReducerTests.SomeError())

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set "Result" to a different case before this reducer ran. This \
        reducer must run before any other reducer sets child state to a different case. This \
        ensures that child reducers can handle their actions while their state is still available.

        • An in-flight effect emitted this action when child state was unavailable. While it may \
        be perfectly reasonable to ignore this action, consider canceling the associated effect \
        before child state changes to another case, especially if it is a long-living effect.

        • This action was sent to the store while state was another case. Make sure that actions \
        for this reducer can only be sent from a view store when state is set to the appropriate \
        case. In SwiftUI applications, use "SwitchStore".
        """
    }

    await store.send(.success(1))
  }

  @MainActor
  func testEffectCancellation_Siblings() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: Reducer {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case timerButtonTapped
          case timerTick
        }
        @Dependency(\.continuousClock) var clock
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .timerButtonTapped:
              return .run { send in
                for await _ in self.clock.timer(interval: .seconds(1)) {
                  await send(.timerTick)
                }
              }
            case .timerTick:
              state.count += 1
              return .none
            }
          }
        }
      }
      struct Parent: Reducer {
        enum State: Equatable {
          case child1(Child.State)
          case child2(Child.State)
        }
        enum Action: Equatable {
          case child1(Child.Action)
          case child1ButtonTapped
          case child2(Child.Action)
          case child2ButtonTapped
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .child1:
              return .none
            case .child1ButtonTapped:
              state = .child1(Child.State())
              return .none
            case .child2:
              return .none
            case .child2ButtonTapped:
              state = .child2(Child.State())
              return .none
            }
          }
          .ifCaseLet(/State.child1, action: /Action.child1) {
            Child()
          }
          .ifCaseLet(/State.child2, action: /Action.child2) {
            Child()
          }
        }
      }
      let clock = TestClock()
      let store = TestStore(initialState: Parent.State.child1(Child.State())) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
      }
      await store.send(.child1(.timerButtonTapped))
      await clock.advance(by: .seconds(1))
      await store.receive(.child1(.timerTick)) {
        try (/Parent.State.child1).modify(&$0) {
          $0.count = 1
        }
      }
      await store.send(.child2ButtonTapped) {
        $0 = .child2(Child.State())
      }
    }
  }

  @MainActor
  func testIdentifiableChild() async {
    struct Feature: Reducer {
      enum State: Equatable {
        case child(Child.State)
      }
      enum Action: Equatable {
        case child(Child.Action)
        case newChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .newChild:
            guard case let .child(childState) = state
            else { return .none }
            state = .child(Child.State(id: childState.id + 1))
            return .none
          }
        }
        .ifCaseLet(/State.child, action: /Action.child) { Child() }
      }
    }
    struct Child: Reducer {
      struct State: Equatable, Identifiable {
        let id: Int
        var value = 0
      }
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.mainQueue) var mainQueue
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .tap:
            return .run { [id = state.id] send in
              try await mainQueue.sleep(for: .seconds(0))
              await send(.response(id))
            }
          case let .response(value):
            state.value = value
            return .none
          }
        }
      }
    }

    let mainQueue = DispatchQueue.test
    let store = TestStore(initialState: Feature.State.child(Child.State(id: 1))) {
      Feature()
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.child(.tap))
    await store.send(.newChild) {
      $0 = .child(Child.State(id: 2))
    }
    await store.send(.child(.tap))
    await mainQueue.advance()
    await store.receive(.child(.response(2))) {
      $0 = .child(Child.State(id: 2, value: 2))
    }
  }
}
