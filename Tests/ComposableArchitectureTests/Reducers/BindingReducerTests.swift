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
        case .binding:
          return .none
        }
      }
    }
  }

  func testEquality() {
    struct State {
      @BindingState var count = 0
    }
    XCTAssertEqual(
      BindingAction<State>.set(\.$count, 1),
      BindingAction<State>.set(\.$count, 1)
    )
    XCTAssertNotEqual(
      BindingAction<State>.set(\.$count, 1),
      BindingAction<State>.set(\.$count, 2)
    )
  }

  func testNestedBindingState() {
    let store = Store(initialState: BindingTest.State()) { BindingTest() }

    let viewStore = ViewStore(store, observe: { $0 })

    viewStore.$nested.field.wrappedValue = "Hello"

    XCTAssertEqual(viewStore.state, .init(nested: .init(field: "Hello!")))
  }

  func testBindingActionUpdatesRespectsPatternMatching() async {
    let testStore = TestStore(
      initialState: BindingTest.State(nested: BindingTest.State.Nested(field: ""))
    ) {
      BindingTest()
    }

    await testStore.send(.binding(.set(\.$nested, BindingTest.State.Nested(field: "special")))) {
      $0.nested = BindingTest.State.Nested(field: "special*")
    }
    await testStore.send(.binding(.set(\.$nested, BindingTest.State.Nested(field: "Hello")))) {
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
