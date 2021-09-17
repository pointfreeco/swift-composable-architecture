import ComposableArchitecture
import XCTest

final class BindingTests: XCTestCase {
  func testNestedBindableState() {
    struct State: Equatable {
      @BindableState var nested = Nested()

      struct Nested: Equatable {
        var field = ""
      }
    }

    enum Action: BindableAction, Equatable {
      case binding(BindingAction<State>)
    }

    let reducer = Reducer<State, Action, ()> { state, action, _ in
      switch action {
      case .binding(\.$nested.field):
        state.nested.field += "!"
        return .none
      default:
        return .none
      }
    }
    .binding()

    let store = Store(initialState: .init(), reducer: reducer, environment: ())

    let viewStore = ViewStore(store)

    viewStore.binding(\.$nested.field).wrappedValue = "Hello"

    XCTAssertNoDifference(viewStore.state, .init(nested: .init(field: "Hello!")))
  }
}
