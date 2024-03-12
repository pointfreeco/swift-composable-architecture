import Combine
@_spi(Internals) import ComposableArchitecture
import SwiftUI
import XCTest

@available(*, deprecated, message: "TODO: Update to use case pathable syntax with Swift 5.9")
final class BindableStoreTests: XCTestCase {
  @MainActor
  func testBindableStore() {
    struct BindableReducer: Reducer {
      struct State: Equatable {
        @BindingState var something: Int
      }

      enum Action: BindableAction {
        case binding(BindingAction<State>)
      }

      var body: some ReducerOf<Self> {
        BindingReducer()
      }
    }

    struct SomeView_BindableViewState: View {
      let store: StoreOf<BindableReducer>

      struct ViewState: Equatable {
        @BindingViewState var something: Int
      }

      var body: some View {
        WithViewStore(store, observe: { ViewState(something: $0.$something) }) { viewStore in
          EmptyView()
        }
      }
    }

    struct SomeView_BindableViewState_Observed: View {
      let store: StoreOf<BindableReducer>
      @ObservedObject var viewStore: ViewStore<ViewState, BindableReducer.Action>

      struct ViewState: Equatable {
        @BindingViewState var something: Int
      }

      init(store: StoreOf<BindableReducer>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { ViewState(something: $0.$something) })
      }

      var body: some View {
        EmptyView()
      }
    }

    struct SomeView_NoBindableViewState: View {
      let store: StoreOf<BindableReducer>

      struct ViewState: Equatable {}

      var body: some View {
        WithViewStore(store, observe: { _ in ViewState() }) { viewStore in
          EmptyView()
        }
      }
    }

    struct SomeView_NoBindableViewState_Observed: View {
      let store: StoreOf<BindableReducer>
      @ObservedObject var viewStore: ViewStore<ViewState, BindableReducer.Action>

      struct ViewState: Equatable {}

      init(store: StoreOf<BindableReducer>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { _ in ViewState() })
      }

      var body: some View {
        EmptyView()
      }
    }
  }

  @MainActor
  func testTestStoreBindings() async {
    struct LoginFeature: Reducer {
      struct State: Equatable {
        @BindingState var email = ""
        public var isFormValid = false
        public var isRequestInFlight = false
        @BindingState var password = ""
      }
      enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case loginButtonTapped
      }
      var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
          switch action {
          case .binding:
            state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
            return .none
          case .loginButtonTapped:
            state.isRequestInFlight = true
            return .none  // NB: Login request
          }
        }
      }
    }

    struct LoginViewState: Equatable {
      @BindingViewState var email: String
      var isFormDisabled: Bool
      var isLoginButtonDisabled: Bool
      @BindingViewState var password: String

      init(_ store: BindingViewStore<LoginFeature.State>) {
        self._email = store.$email
        self.isFormDisabled = store.isRequestInFlight
        self.isLoginButtonDisabled = !store.isFormValid || store.isRequestInFlight
        self._password = store.$password
      }
    }

    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    }
    await store.send(.set(\.$email, "blob@pointfree.co")) {
      $0.email = "blob@pointfree.co"
    }
    XCTAssertFalse(LoginViewState(store.bindings).isFormDisabled)
    XCTAssertTrue(LoginViewState(store.bindings).isLoginButtonDisabled)
    await store.send(.set(\.$password, "blob123")) {
      $0.password = "blob123"
      $0.isFormValid = true
    }
    XCTAssertFalse(LoginViewState(store.bindings).isFormDisabled)
    XCTAssertFalse(LoginViewState(store.bindings).isLoginButtonDisabled)
    await store.send(.loginButtonTapped) {
      $0.isRequestInFlight = true
    }
    XCTAssertTrue(LoginViewState(store.bindings).isFormDisabled)
    XCTAssertTrue(LoginViewState(store.bindings).isLoginButtonDisabled)
  }

  @MainActor
  func testTestStoreBindings_ViewAction() async {
    struct LoginFeature: Reducer {
      struct State: Equatable {
        @BindingState var email = ""
        public var isFormValid = false
        public var isRequestInFlight = false
        @BindingState var password = ""
      }
      enum Action: Equatable {
        case view(View)
        enum View: Equatable, BindableAction {
          case binding(BindingAction<State>)
          case loginButtonTapped
        }
      }
      var body: some ReducerOf<Self> {
        BindingReducer(action: /Action.view)
        Reduce { state, action in
          switch action {
          case .view(.binding):
            state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
            return .none
          case .view(.loginButtonTapped):
            state.isRequestInFlight = true
            return .none  // NB: Login request
          }
        }
      }
    }

    struct LoginViewState: Equatable {
      @BindingViewState var email: String
      var isFormDisabled: Bool
      var isLoginButtonDisabled: Bool
      @BindingViewState var password: String

      init(_ store: BindingViewStore<LoginFeature.State>) {
        self._email = store.$email
        self.isFormDisabled = store.isRequestInFlight
        self.isLoginButtonDisabled = !store.isFormValid || store.isRequestInFlight
        self._password = store.$password
      }
    }

    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    }
    await store.send(.view(.set(\.$email, "blob@pointfree.co"))) {
      $0.email = "blob@pointfree.co"
    }
    XCTAssertFalse(
      LoginViewState(store.bindings(action: /LoginFeature.Action.view)).isFormDisabled
    )
    XCTAssertTrue(
      LoginViewState(store.bindings(action: /LoginFeature.Action.view)).isLoginButtonDisabled
    )
    await store.send(.view(.set(\.$password, "blob123"))) {
      $0.password = "blob123"
      $0.isFormValid = true
    }
    XCTAssertFalse(
      LoginViewState(store.bindings(action: /LoginFeature.Action.view)).isFormDisabled
    )
    XCTAssertFalse(
      LoginViewState(store.bindings(action: /LoginFeature.Action.view)).isLoginButtonDisabled
    )
    await store.send(.view(.loginButtonTapped)) {
      $0.isRequestInFlight = true
    }
    XCTAssertTrue(
      LoginViewState(store.bindings(action: /LoginFeature.Action.view)).isFormDisabled
    )
    XCTAssertTrue(
      LoginViewState(store.bindings(action: /LoginFeature.Action.view)).isLoginButtonDisabled
    )
  }
}
