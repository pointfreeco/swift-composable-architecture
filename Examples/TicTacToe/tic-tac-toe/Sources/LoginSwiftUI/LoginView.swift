import AuthenticationClient
import ComposableArchitecture
import LoginCore
import SwiftUI
import TwoFactorCore
import TwoFactorSwiftUI

public struct LoginView: View {
  let store: StoreOf<Login>

  struct ViewState: Equatable {
    @BindingViewState var email: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isLoginButtonDisabled: Bool
    @BindingViewState var password: String
  }

  public init(store: StoreOf<Login>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store, observe: \.view, send: { .view($0) }) { viewStore in
      Form {
        Text(
          """
          To login use any email and "password" for the password. If your email contains the \
          characters "2fa" you will be taken to a two-factor flow, and on that screen you can \
          use "1234" for the code.
          """
        )

        Section {
          TextField("blob@pointfree.co", text: viewStore.$email)
            .autocapitalization(.none)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)

          SecureField("••••••••", text: viewStore.$password)
        }

        Button {
          // NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected" if
          //     you disable a text field while it is focused. This hack will force all fields to
          //     unfocus before we send the action to the view store.
          // CF: https://stackoverflow.com/a/69653555
          _ = UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
          )
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
      .alert(store: self.store.scope(state: \.$alert, action: \.alert))
      .navigationDestination(
        store: self.store.scope(state: \.$twoFactor, action: \.twoFactor),
        destination: TwoFactorView.init
      )
    }
    .navigationTitle("Login")
  }
}

extension BindingViewStore<Login.State> {
  var view: LoginView.ViewState {
    LoginView.ViewState(
      email: self.$email,
      isActivityIndicatorVisible: self.isLoginRequestInFlight,
      isFormDisabled: self.isLoginRequestInFlight,
      isLoginButtonDisabled: !self.isFormValid,
      password: self.$password
    )
  }
}

struct LoginView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      LoginView(
        store: Store(initialState: Login.State()) {
          Login()
        } withDependencies: {
          $0.authenticationClient.login = { _ in
            AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
          }
          $0.authenticationClient.twoFactor = { _ in
            AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
          }
        }
      )
    }
  }
}
