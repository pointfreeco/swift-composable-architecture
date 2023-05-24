import ComposableArchitecture
import XCTest

@MainActor
final class BindingTests: BaseTCATestCase {
  func testNestedBindingState() {
    struct BindingTest: Reducer {
      struct State: Equatable {
        @BindingState var nested = Nested()

        struct Nested: Equatable {
          var field = ""
        }
      }

      enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
      }

      var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
          switch action {
          case .binding(\.$nested.field):
            state.nested.field += "!"
            return .none
          default:
            return .none
          }
        }
      }
    }

    let store = Store(initialState: BindingTest.State()) { BindingTest() }

    let viewStore = ViewStore(store, observe: { $0 })

    viewStore.binding(\.$nested.field).wrappedValue = "Hello"

    XCTAssertEqual(viewStore.state, .init(nested: .init(field: "Hello!")))
  }

  // NB: This crashes in Swift(<5.8) RELEASE when `BindingAction` holds directly onto an unboxed
  //     `value: Any` existential
  func testLayoutBug() {
    enum Foo {
      case bar(Baz)
    }
    enum Baz {
      case fizz(BindingAction<Void>)
      case buzz(Bool)
    }
    _ = (/Foo.bar).extract(from: .bar(.buzz(true)))
  }
}
