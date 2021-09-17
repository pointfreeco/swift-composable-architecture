import ComposableArchitecture
import XCTest

final class BindingTests: XCTestCase {
  func testNestedBindableState() {
    struct State: Equatable {
      @BindableState var nested = Nested()

      struct Nested: Equatable {
        @BindableState var field = ""
        var more = More()

        struct More: Equatable {
          var more =  ""
        }
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

    // TODO: `let` breaks this, fix with reference writable key path
    let viewStore = ViewStore(store)

     viewStore.$nested.$field.wrappedValue.wrappedValue = "Hello"
//    viewStore.$nested.more.more.wrappedValue = "Hello"

    XCTAssertNoDifference(viewStore.state, .init(nested: .init(field: "Hello!")))
  }
}
