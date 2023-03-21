import ComposableArchitecture
import XCTest

@MainActor
final class StackReducerTests: XCTestCase {
  func testPresent() async {
    struct Child: ReducerProtocol {
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
          return .none
        case .incrementButtonTapped:
          state.count += 1
          return .none
        }
      }
    }
    struct Parent: ReducerProtocol {
      struct State: Equatable {
        var children: StackState<Child.State> = []
      }
      enum Action: Equatable {
        case children(StackAction<Child.Action>)
        case pushChild
      }
      var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
          switch action {
          case .children:
            return .none
          case .pushChild:
            state.children.append(Child.State())
            return .none
          }
        }
        .forEach(\.children, action: /Action.children) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State(), reducer: Parent())

    await store.send(.pushChild) {
      $0.children = [
        Child.State()
      ]
    }
  }
}
