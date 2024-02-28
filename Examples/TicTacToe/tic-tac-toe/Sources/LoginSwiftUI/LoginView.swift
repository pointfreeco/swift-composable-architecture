import AuthenticationClient
import ComposableArchitecture
import LoginCore
import SwiftUI
import TwoFactorCore
import TwoFactorSwiftUI

@ViewAction(for: Login.self)
public struct LoginView: View {
  @Bindable public var store: StoreOf<Login>

  public init(store: StoreOf<Login>) {
    self.store = store
  }

  public var body: some View {
    Form {
      Text(
        """
        To login use any email and "password" for the password. If your email contains the \
        characters "2fa" you will be taken to a two-factor flow, and on that screen you can \
        use "1234" for the code.
        """
      )

      Section {
        TextField("blob@pointfree.co", text: $store.email)
          .autocapitalization(.none)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)

        SecureField("••••••••", text: $store.password)
      }

      Button {
        // NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected" if
        //     you disable a text field while it is focused. This hack will force all fields to
        //     unfocus before we send the action to the store.
        // CF: https://stackoverflow.com/a/69653555
        _ = UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        send(.loginButtonTapped)
      } label: {
        HStack {
          Text("Log in")
          if store.isActivityIndicatorVisible {
            Spacer()
            ProgressView()
          }
        }
      }
      .disabled(store.isLoginButtonDisabled)
    }
    .disabled(store.isFormDisabled)
    .alert($store.scope(state: \.alert, action: \.alert))
    .navigationDestination(item: $store.scope(state: \.twoFactor, action: \.twoFactor)) { store in
      TwoFactorView(store: store)
    }
    .navigationTitle("Login")
  }
}

extension Login.State {
  fileprivate var isActivityIndicatorVisible: Bool { self.isLoginRequestInFlight }
  fileprivate var isFormDisabled: Bool { self.isLoginRequestInFlight }
  fileprivate var isLoginButtonDisabled: Bool { !self.isFormValid }
}

#Preview {
  NavigationStack {
    LoginView(
      store: Store(initialState: Login.State()) {
        Login()
      } withDependencies: {
        $0.authenticationClient.login = { @Sendable _, _ in
          AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
        }
        $0.authenticationClient.twoFactor = { @Sendable _, _ in
          AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
        }
      }
    )
  }
}
