import ComposableArchitecture
import XCTest

@MainActor
final class ScopeTests: XCTestCase {
  func testStructChild() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.child1(.incrementButtonTapped)) {
      $0.child1.count = 1
    }
    await store.send(.child1(.decrementButtonTapped)) {
      $0.child1.count = 0
    }
    await store.send(.child1(.decrementButtonTapped)) {
      $0.child1.count = -1
    }
    await store.receive(.child1(.incrementButtonTapped)) {
      $0.child1.count = 0
    }
  }

  func testEnumChild() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.child2(.count(1))) {
      $0.child2 = .count(1)
    }
    await store.send(.child2(.count(-1))) {
      $0.child2 = .count(-1)
    }
    await store.receive(.child2(.count(0))) {
      $0.child2 = .count(0)
    }
  }

  #if DEBUG
    func testNilChild() async {
      let store = TestStore(
        initialState: Child2.State.count(0),
        reducer: Scope(state: /Child2.State.name, action: /Child2.Action.name) {}
      )

      XCTExpectFailure {
        $0.compactDescription == """
          A "Scope" at "\(#fileID):\(#line - 5)" received a child action when child state was set to \
          a different case. …

            Action:
              Child2.Action.name
            State:
              Child2.State.count

          This is generally considered an application logic error, and can happen for a few reasons:

          • A parent reducer set "Child2.State" to a different case before the scoped reducer ran. \
          Child reducers must run before any parent reducer sets child state to a different case. \
          This ensures that child reducers can handle their actions while their state is still \
          available. Consider using "ReducerProtocol.ifCaseLet" to embed this child reducer in the \
          parent reducer that change its state to ensure the child reducer runs first.

          • An in-flight effect emitted this action when child state was unavailable. While it may \
          be perfectly reasonable to ignore this action, consider canceling the associated effect \
          before child state changes to another case, especially if it is a long-living effect.

          • This action was sent to the store while state was another case. Make sure that actions \
          for this reducer can only be sent from a view store when state is set to the appropriate \
          case. In SwiftUI applications, use "SwitchStore".
          """
      }

      await store.send(.name("Blob"))
    }
  #endif
}

private struct Feature: ReducerProtocol {
  struct State: Equatable {
    var child1 = Child1.State()
    var child2 = Child2.State.count(0)
  }
  enum Action: Equatable {
    case child1(Child1.Action)
    case child2(Child2.Action)
  }
  #if swift(>=5.7)
    var body: some ReducerProtocol<State, Action> {
      Scope(state: \.child1, action: /Action.child1) {
        Child1()
      }
      Scope(state: \.child2, action: /Action.child2) {
        Child2()
      }
    }
  #else
    var body: Reduce<State, Action> {
      Scope(state: \.child1, action: /Action.child1) {
        Child1()
      }
      Scope(state: \.child2, action: /Action.child2) {
        Child2()
      }
    }
  #endif
}

private struct Child1: ReducerProtocol {
  struct State: Equatable {
    var count = 0
  }
  enum Action: Equatable {
    case decrementButtonTapped
    case incrementButtonTapped
  }
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .decrementButtonTapped:
      state.count -= 1
      return state.count < 0
        ? .run { await $0(.incrementButtonTapped) }
        : .none
    case .incrementButtonTapped:
      state.count += 1
      return .none
    }
  }
}

private struct Child2: ReducerProtocol {
  enum State: Equatable {
    case count(Int)
    case name(String)
  }
  enum Action: Equatable {
    case count(Int)
    case name(String)
  }
  #if swift(>=5.7)
    var body: some ReducerProtocol<State, Action> {
      Scope(state: /State.count, action: /Action.count) {
        Reduce { state, action in
          state = action
          return state < 0
            ? .run { await $0(0) }
            : .none
        }
      }
      Scope(state: /State.name, action: /Action.name) {
        Reduce { state, action in
          state = action
          return state.isEmpty
            ? .run { await $0("Empty") }
            : .none
        }
      }
    }
  #else
    var body: Reduce<State, Action> {
      Scope(state: /State.count, action: /Action.count) {
        Reduce { state, action in
          state = action
          return state < 0
            ? .run { await $0(0) }
            : .none
        }
      }
      Scope(state: /State.name, action: /Action.name) {
        Reduce { state, action in
          state = action
          return state.isEmpty
            ? .run { await $0("Empty") }
            : .none
        }
      }
    }
  #endif
}
