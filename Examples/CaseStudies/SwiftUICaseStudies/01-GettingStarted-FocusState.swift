import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to make use of SwiftUI's `@FocusState` in the Composable Architecture with \
  the library's `bind` view modifier. If you tap the "Sign in" button while a field is empty, the \
  focus will be changed to the first empty field.
  """

@Reducer
struct FocusDemo {
  @ObservableState
  struct State: Equatable {
    var focusedField: Field?
    var password: String = ""
    var username: String = ""

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

struct FocusDemoView: View {
  @Bindable var store: StoreOf<FocusDemo>
  @FocusState var focusedField: FocusDemo.State.Field?

  var body: some View {
    Form {
      AboutView(readMe: readMe)

      VStack {
        TextField("Username", text: $store.username)
          .focused($focusedField, equals: .username)
        SecureField("Password", text: $store.password)
          .focused($focusedField, equals: .password)
        Button("Sign In") {
          store.send(.signInButtonTapped)
        }
        .buttonStyle(.borderedProminent)
      }
      .textFieldStyle(.roundedBorder)
    }
    // Synchronize store focus state and local focus state.
    .bind($store.focusedField, to: $focusedField)
    .navigationTitle("Focus demo")
  }
}

#Preview {
  NavigationStack {
    FocusDemoView(
      store: Store(initialState: FocusDemo.State()) {
        FocusDemo()
      }
    )
  }
}
