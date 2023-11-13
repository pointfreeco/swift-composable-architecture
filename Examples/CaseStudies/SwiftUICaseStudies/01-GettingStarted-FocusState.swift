import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to make use of SwiftUI's `@FocusState` in the Composable Architecture with \
  the library's `bind` view modifier. If you tap the "Sign in" button while a field is empty, the \
  focus will be changed to that field.
  """

// MARK: - Feature domain

@Reducer
struct FocusDemo {
  struct State: Equatable {
    @BindingState var focusedField: Field?
    @BindingState var password: String = ""
    @BindingState var username: String = ""

    enum Field: String, Hashable {
      case username, password
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case signInButtonTapped
  }

  var body: some Reducer<State, Action> {
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
  @State var store = Store(initialState: FocusDemo.State()) {
    FocusDemo()
  }
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
      // Synchronize store focus state and local focus state.
      .bind(viewStore.$focusedField, to: self.$focusedField)
    }
    .navigationTitle("Focus demo")
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
