import AuthenticationClient
import ComposableArchitecture
import LoginCore
import SwiftUI
import TicTacToeCommon
import TwoFactorCore
import TwoFactorSwiftUI

public struct LoginView: View {
  let store: Store<LoginState, LoginAction>

  struct ViewState: Equatable {
    var alert: AlertState<LoginAction>?
    var email: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isLoginButtonDisabled: Bool
    var password: String
    var isTwoFactorActive: Bool

    init(state: LoginState) {
      self.alert = state.alert
      self.email = state.email
      self.isActivityIndicatorVisible = state.isLoginRequestInFlight
      self.isFormDisabled = state.isLoginRequestInFlight
      self.isLoginButtonDisabled = !state.isFormValid
      self.password = state.password
      self.isTwoFactorActive = state.twoFactor != nil
    }
  }

  enum ViewAction {
    case alertDismissed
    case emailChanged(String)
    case onAppear
    case passwordChanged(String)
  }

  public init(store: Store<LoginState, LoginAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init, action: LoginAction.init)) { viewStore in
      ScrollView {
        VStack(spacing: 16) {
          Text(
            """
            To login use any email and "password" for the password. If your email contains the \
            characters "2fa" you will be taken to a two-factor flow, and on that screen you can \
            use "1234" for the code.
            """
          )

          VStack(alignment: .leading) {
            Text("Email")
            TextField(
              "blob@pointfree.co",
              text: viewStore.binding(get: \.email, send: ViewAction.emailChanged)
            )
            .autocapitalization(.none)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textFieldStyle(RoundedBorderTextFieldStyle())
          }

          VStack(alignment: .leading) {
            Text("Password")
            SecureField(
              "••••••••",
              text: viewStore.binding(get: \.password, send: ViewAction.passwordChanged)
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
          }

          NavigationLinkStore(
            destination: TwoFactorView.init(store:),
            ifLet: self.store.scope(state: \.twoFactor, action: LoginAction.twoFactor)
          ) {
            Text("Log in")

            if viewStore.isActivityIndicatorVisible {
              ActivityIndicator()
            }
          }
          .disabled(viewStore.isLoginButtonDisabled)
        }
        .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
        .disabled(viewStore.isFormDisabled)
        .padding(.horizontal)
        .onAppear { viewStore.send(.onAppear) }
      }
    }
    .navigationBarTitle("Login")
  }
}

extension LoginAction {
  init(action: LoginView.ViewAction) {
    switch action {
    case .alertDismissed:
      self = .alertDismissed
    case let .emailChanged(email):
      self = .emailChanged(email)
    case .onAppear:
      self = .onAppear
    case let .passwordChanged(password):
      self = .passwordChanged(password)
    }
  }
}

struct LoginView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoginView(
        store: Store(
          initialState: LoginState(),
          reducer: loginReducer,
          environment: LoginEnvironment(
            authenticationClient: AuthenticationClient(
              login: { _ in Effect(value: .init(token: "deadbeef", twoFactorRequired: false)) },
              twoFactor: { _ in Effect(value: .init(token: "deadbeef", twoFactorRequired: false)) }
            ),
            mainQueue: .main
          )
        )
      )
    }
  }
}
