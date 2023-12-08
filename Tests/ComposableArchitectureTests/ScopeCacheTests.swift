@_spi(Internals) import ComposableArchitecture
import XCTest

class ScopeCacheTests: XCTestCase {
  func testBasics() {
    let store = Store(initialState: Parent.State(child: Child.State())) {
      Parent()
    }
    let childStore = store.scope(state: \.child, action: \.child)
    let unwrappedChildStore = childStore.scope(
      state: { $0! },
      id: childStore.id(state: \.!, action: \.self),
      action: { $0 },
      isInvalid: { $0 == nil },
      removeDuplicates: nil
    )
    unwrappedChildStore.send(.dismiss)
    XCTAssertEqual(store.stateSubject.value.child, nil)
  }
}

@Reducer
private struct Parent {
  struct State {
    @PresentationState var child: Child.State?
  }
  enum Action {
    case child(PresentationAction<Child.Action>)
    case show
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .child(.presented(.dismiss)):
        state.child = nil
        return .none
      case .child:
        return .none
      case .show:
        state.child = Child.State()
        return .none
      }
    }
    .ifLet(\.$child, action: \.child) {
      Child()
    }
  }
}
@Reducer
private struct Child {
  struct State: Equatable {}
  enum Action { case dismiss }
  var body: some ReducerOf<Self> { EmptyReducer() }
}
