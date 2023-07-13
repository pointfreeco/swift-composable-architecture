import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to make use of SwiftUI's `@FocusState` in the Composable Architecture. \
  If you tap the "Sign in" button while a field is empty, the focus will be changed to that field.
  """

// MARK: - Feature domain

struct FocusDemo: ReducerProtocol {
  struct State: Equatable {
    @BindingState var focusedField: Field?
    @BindingState var password: String = ""
    @BindingState var username: String = ""

    enum Field: String, Hashable {
      case username, password
    }
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case signInButtonTapped
  }

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .signInButtonTapped:
        if state.username.isEmpty {
          state.focusedField = .username
        } else if state.password.isEmpty {
          state.focusedField = .password
        }
        return .none
      }
    }
  }
}

// MARK: - Feature view

struct FocusDemoView: View {
  let store: StoreOf<FocusDemo>
  @FocusState var focusedField: FocusDemo.State.Field?

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        AboutView(readMe: readMe)

        VStack {
          TextField("Username", text: viewStore.$username)
            .focused($focusedField, equals: .username)
          SecureField("Password", text: viewStore.$password)
            .focused($focusedField, equals: .password)
          Button("Sign In") {
            viewStore.send(.signInButtonTapped)
          }
          .buttonStyle(.borderedProminent)
        }
        .textFieldStyle(.roundedBorder)
      }
      .synchronize(viewStore.$focusedField, self.$focusedField)
    }
    .navigationTitle("Focus demo")
  }
}

extension View {
  func synchronize<Value>(
    _ first: Binding<Value>,
    _ second: FocusState<Value>.Binding
  ) -> some View {
    self
      .onChange(of: first.wrappedValue) { second.wrappedValue = $0 }
      .onChange(of: second.wrappedValue) { first.wrappedValue = $0 }
  }
}

// MARK: - SwiftUI previews

struct FocusDemo_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      FocusDemoView(
        store: Store(initialState: FocusDemo.State()) {
          FocusDemo()
        }
      )
    }
  }
}
