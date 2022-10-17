import AuthenticationClient
import ComposableArchitecture
import LoginCore
import SwiftUI
import TwoFactorCore
import TwoFactorSwiftUI

public struct LoginView: View {
  let store: StoreOf<Login>

  struct ViewState: Equatable {
    var alert: AlertState<Login.Action>?
    var email: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isLoginButtonDisabled: Bool
    var password: String
    var isTwoFactorActive: Bool

    init(state: Login.State) {
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
    case loginButtonTapped
    case passwordChanged(String)
    case twoFactorDismissed
  }

  public init(store: StoreOf<Login>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store, observe: ViewState.init, send: Login.Action.init) { viewStore in
      Form {
        Text(
          """
          To login use any email and "password" for the password. If your email contains the \
          characters "2fa" you will be taken to a two-factor flow, and on that screen you can \
          use "1234" for the code.
          """
        )

        Section {
          TextField(
            "blob@pointfree.co",
            text: viewStore.binding(get: \.email, send: ViewAction.emailChanged)
          )
          .autocapitalization(.none)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)

          SecureField(
            "••••••••",
            text: viewStore.binding(get: \.password, send: ViewAction.passwordChanged)
          )
        }

        NavigationLink(
          destination: IfLetStore(
            self.store.scope(state: \.twoFactor, action: Login.Action.twoFactor)
          ) {
            TwoFactorView(store: $0)
          },
          isActive: viewStore.binding(
            get: \.isTwoFactorActive,
            send: {
              // NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected"
              //     if you disable a text field while it is focused. This hack will force all
              //     fields to unfocus before we send the action to the view store.
              // CF: https://stackoverflow.com/a/69653555
              _ = UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
              )
              return $0 ? .loginButtonTapped : .twoFactorDismissed
            }
          )
        ) {
          Text("Log in")
          if viewStore.isActivityIndicatorVisible {
            Spacer()
            ProgressView()
          }
        }
        .disabled(viewStore.isLoginButtonDisabled)
      }
      .disabled(viewStore.isFormDisabled)
      .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
    }
    .navigationTitle("Login")
  }
}

extension Login.Action {
  init(action: LoginView.ViewAction) {
    switch action {
    case .alertDismissed:
      self = .alertDismissed
    case .twoFactorDismissed:
      self = .twoFactorDismissed
    case let .emailChanged(email):
      self = .emailChanged(email)
    case .loginButtonTapped:
      self = .loginButtonTapped
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
          initialState: Login.State(),
          reducer: Login()
            .dependency(\.authenticationClient.login) { _ in
              AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
            }
            .dependency(\.authenticationClient.twoFactor) { _ in
              AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
            }
        )
      )
    }
  }
}
