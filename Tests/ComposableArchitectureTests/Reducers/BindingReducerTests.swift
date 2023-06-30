import ComposableArchitecture
import XCTest

@MainActor
final class BindingTests: BaseTCATestCase {
  struct BindingTest: ReducerProtocol {
    struct State: Equatable {
      @BindingState var nested = Nested()

      struct Nested: Equatable {
        var field = ""
      }
    }

    enum Action: BindableAction, Equatable {
      case binding(BindingAction<State>)
    }

    var body: some ReducerProtocol<State, Action> {
      BindingReducer()
      Reduce { state, action in
        switch action {
          case .binding(.set(\.$nested, State.Nested(field: "special"))):
              state.nested.field += "*"
              return .none
          case .binding(\.$nested):
            state.nested.field += "!"
            return .none
          default:
            return .none
        }
      }
    }
  }
    
  func testNestedBindingState() {
    let store = Store(initialState: BindingTest.State()) { BindingTest() }

    let viewStore = ViewStore(store, observe: { $0 })

    viewStore.$nested.field.wrappedValue = "Hello"

    XCTAssertEqual(viewStore.state, .init(nested: .init(field: "Hello!")))
  }
    
  func testBindingActionUpdatesRespectsPatternMatching() async {
    let testStore = TestStore<
      BindingTest.State,
      BindingTest.Action,
      BindingTest.State,
      BindingTest.Action,
      Void
    >(initialState: .init(nested: .init(field: "")), reducer: BindingTest())
    
    await testStore.send(.binding(.set(\.$nested, .init(field: "special")))) {
        $0.nested = BindingTest.State.Nested(field: "special*")
    }
  }
    
  func testBindingActionUpdatesMatchingAnyValue() async {
    let testStore = TestStore<
       BindingTest.State,
       BindingTest.Action,
       BindingTest.State,
       BindingTest.Action,
       Void
     >(initialState: .init(nested: .init(field: "")), reducer: BindingTest())
       
     await testStore.send(.binding(.set(\.$nested, .init(field: "Hello")))) {
         $0.nested = BindingTest.State.Nested(field: "Hello!")
     }
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
