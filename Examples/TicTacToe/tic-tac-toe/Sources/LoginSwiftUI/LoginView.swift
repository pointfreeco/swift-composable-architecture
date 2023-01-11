import AuthenticationClient
import ComposableArchitecture
import LoginCore
import SwiftUI
import TwoFactorCore
import TwoFactorSwiftUI

public struct LoginView: View {
  let store: StoreOf<Login>

  struct ViewState: Equatable {
    var email: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isLoginButtonDisabled: Bool
    var password: String

    init(state: Login.State) {
      self.email = state.email
      self.isActivityIndicatorVisible = state.isLoginRequestInFlight
      self.isFormDisabled = state.isLoginRequestInFlight
      self.isLoginButtonDisabled = !state.isFormValid
      self.password = state.password
    }
  }

  enum ViewAction {
    case emailChanged(String)
    case loginButtonTapped
    case passwordChanged(String)
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

        Button {
          viewStore.send(.loginButtonTapped)
        } label: {
          HStack {
            Text("Log in")
            if viewStore.isActivityIndicatorVisible {
              Spacer()
              ProgressView()
            }
          }
        }
        .disabled(viewStore.isLoginButtonDisabled)
      }
      .disabled(viewStore.isFormDisabled)
      .alert(
        store: self.store.scope(state: \.$destination, action: Login.Action.destination),
        state: /Login.Destinations.State.alert,
        action: Login.Destinations.Action.alert
      )
    }
    .navigationTitle("Login")
    .navigationDestination(
      store: self.store.scope(state: \.$destination, action: Login.Action.destination),
      state: /Login.Destinations.State.twoFactor,
      action: Login.Destinations.Action.twoFactor,
      destination: TwoFactorView.init(store:)
    )
  }
}

extension Login.Action {
  init(action: LoginView.ViewAction) {
    switch action {
    case let .emailChanged(email):
      self = .emailChanged(email)
    case .loginButtonTapped:
      self = .destination(.present(id: ObjectIdentifier(TwoFactor.self)))
    case let .passwordChanged(password):
      self = .passwordChanged(password)
    }
  }
}

struct LoginView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
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
