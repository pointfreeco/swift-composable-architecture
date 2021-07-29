import ComposableArchitecture
import SwiftUI

struct LoginState: Equatable {
  var focusedField: Field? = nil
  var password: String = ""
  var username: String = ""

  enum Field: String, Hashable {
    case username, password
  }
}

enum LoginAction {
  case binding(BindingAction<LoginState>)
//  case setFocusedField(LoginState.Field?)
//  case setPassword(String)
//  case setUsername(String)
  case signInButtonTapped
}

struct LoginEnvironment {
}

let loginReducer = Reducer<
  LoginState,
  LoginAction,
  LoginEnvironment
> { state, action, environment in
  switch action {
//  case .binding(\.username):
//    return .none

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
.binding(action: /LoginAction.binding)

struct TcaLoginView: View {
  @FocusState var focusedField: LoginState.Field?
  let store: Store<LoginState, LoginAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        TextField(
          "Username",
          text: viewStore.binding(keyPath: \.username, send: LoginAction.binding)
        )
          .focused($focusedField, equals: .username)

        SecureField(
          "Password",
          text: viewStore.binding(keyPath: \.password, send: LoginAction.binding)
        )
          .focused($focusedField, equals: .password)

        Button("Sign In") {
          viewStore.send(.signInButtonTapped)
        }

        Text("\(String(describing: viewStore.focusedField))")
      }
//      .onChange(of: viewStore.focusedField) {
//        self.focusedField = $0
//      }
//      .onChange(of: self.focusedField) { newValue in
//        viewStore.send(.binding(.set(\.focusedField, newValue)))
//      }
      .synchronize(
        viewStore.binding(keyPath: \.focusedField, send: LoginAction.binding),
        self.$focusedField
      )
    }
  }
}
