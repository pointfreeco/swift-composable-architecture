import AuthenticationClient
import ComposableArchitecture
import SwiftUI
import TwoFactorCore

public struct TwoFactorView: View {
  let store: StoreOf<TwoFactor>

  struct ViewState: Equatable {
    @BindingViewState var code: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isSubmitButtonDisabled: Bool
  }

  public init(store: StoreOf<TwoFactor>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store, observe: \.view, send: { .view($0) }) { viewStore in
      Form {
        Text(#"To confirm the second factor enter "1234" into the form."#)

        Section {
          TextField("1234", text: viewStore.$code)
            .keyboardType(.numberPad)
        }

        HStack {
          Button("Submit") {
            // NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected"
            //     if you disable a text field while it is focused. This hack will force all
            //     fields to unfocus before we send the action to the view store.
            // CF: https://stackoverflow.com/a/69653555
            UIApplication.shared.sendAction(
              #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
            viewStore.send(.submitButtonTapped)
          }
          .disabled(viewStore.isSubmitButtonDisabled)

          if viewStore.isActivityIndicatorVisible {
            Spacer()
            ProgressView()
          }
        }
      }
      .alert(store: self.store.scope(state: \.$alert, action: \.alert))
      .disabled(viewStore.isFormDisabled)
      .navigationTitle("Confirmation Code")
    }
  }
}

extension BindingViewStore<TwoFactor.State> {
  var view: TwoFactorView.ViewState {
    TwoFactorView.ViewState(
      code: self.$code,
      isActivityIndicatorVisible: self.isTwoFactorRequestInFlight,
      isFormDisabled: self.isTwoFactorRequestInFlight,
      isSubmitButtonDisabled: !self.isFormValid
    )
  }
}

struct TwoFactorView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      TwoFactorView(
        store: Store(initialState: TwoFactor.State(token: "deadbeef")) {
          TwoFactor()
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
