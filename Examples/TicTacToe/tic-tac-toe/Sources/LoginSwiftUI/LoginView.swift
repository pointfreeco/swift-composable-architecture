import AuthenticationClient
import ComposableArchitecture
import LoginCore
import SwiftUI
import TwoFactorCore
import TwoFactorSwiftUI

public struct LoginView: View {
  let store: Store<LoginState, LoginAction>

  struct ViewState: Equatable {
    var alert: AlertState<LoginAction>?
    @BindableState var email: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isLoginButtonDisabled: Bool
    @BindableState var password: String
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

  enum ViewAction: BindableAction {
    case alertDismissed
    case binding(BindingAction<ViewState>)
    case loginButtonTapped
    case twoFactorDismissed
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
            TextField("blob@pointfree.co", text: viewStore.$email)
              .autocapitalization(.none)
              .keyboardType(.emailAddress)
              .textContentType(.emailAddress)
              .textFieldStyle(RoundedBorderTextFieldStyle())
          }

          VStack(alignment: .leading) {
            Text("Password")
            SecureField("••••••••", text: viewStore.$password)
              .textFieldStyle(RoundedBorderTextFieldStyle())
          }

          NavigationLink(
            destination: IfLetStore(
              self.store.scope(state: \.twoFactor, action: LoginAction.twoFactor),
              then: TwoFactorView.init(store:)
            ),
            isActive: viewStore.binding(
              get: \.isTwoFactorActive,
              send: { $0 ? .loginButtonTapped : .twoFactorDismissed }
            )
          ) {
            Text("Log in")

            if viewStore.isActivityIndicatorVisible {
              ProgressView()
            }
          }
          .disabled(viewStore.isLoginButtonDisabled)
        }
        .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
        .disabled(viewStore.isFormDisabled)
        .padding(.horizontal)
      }
    }
    .navigationBarTitle("Login")
  }
}

extension LoginState {
  var view: LoginView.ViewState {
    get { .init(state: self) }
    set {
      // handle bindable actions only:
      self.email = newValue.email
      self.password = newValue.password
    }
  }
}

extension LoginAction {
  init(action: LoginView.ViewAction) {
    switch action {
    case .alertDismissed:
      self = .alertDismissed
    case let .binding(bindingAction):
      self = .binding(bindingAction.pullback(\LoginState.view))
    case .loginButtonTapped:
      self = .loginButtonTapped
    case .twoFactorDismissed:
      self = .twoFactorDismissed
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
