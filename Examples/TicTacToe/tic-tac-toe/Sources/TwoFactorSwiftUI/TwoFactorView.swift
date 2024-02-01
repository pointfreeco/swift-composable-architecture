import AuthenticationClient
import ComposableArchitecture
import SwiftUI
import TwoFactorCore

@ViewAction(for: TwoFactor.self)
public struct TwoFactorView: View {
  @Bindable public var store: StoreOf<TwoFactor>

  public init(store: StoreOf<TwoFactor>) {
    self.store = store
  }

  public var body: some View {
    Form {
      Text(#"To confirm the second factor enter "1234" into the form."#)

      Section {
        TextField("1234", text: $store.code)
          .keyboardType(.numberPad)
      }

      HStack {
        Button("Submit") {
          // NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected"
          //     if you disable a text field while it is focused. This hack will force all
          //     fields to unfocus before we send the action to the store.
          // CF: https://stackoverflow.com/a/69653555
          UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
          )
          send(.submitButtonTapped)
        }
        .disabled(store.isSubmitButtonDisabled)

        if store.isActivityIndicatorVisible {
          Spacer()
          ProgressView()
        }
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
    .disabled(store.isFormDisabled)
    .navigationTitle("Confirmation Code")
  }
}

extension TwoFactor.State {
  fileprivate var isActivityIndicatorVisible: Bool { self.isTwoFactorRequestInFlight }
  fileprivate var isFormDisabled: Bool { self.isTwoFactorRequestInFlight }
  fileprivate var isSubmitButtonDisabled: Bool { !self.isFormValid }
}

#Preview {
  NavigationStack {
    TwoFactorView(
      store: Store(initialState: TwoFactor.State(token: "deadbeef")) {
        TwoFactor()
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
