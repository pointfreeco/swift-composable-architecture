import AuthenticationClient
import ComposableArchitecture
import SwiftUI
import TwoFactorCore

public struct TwoFactorView: View {
  let store: StoreOf<TwoFactor>

  struct ViewState: Equatable {
    var alert: AlertState<TwoFactor.Action>?
    var code: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isSubmitButtonDisabled: Bool

    init(state: TwoFactor.State) {
      self.alert = state.alert
      self.code = state.code
      self.isActivityIndicatorVisible = state.isTwoFactorRequestInFlight
      self.isFormDisabled = state.isTwoFactorRequestInFlight
      self.isSubmitButtonDisabled = !state.isFormValid
    }
  }

  enum ViewAction: Equatable {
    case alertDismissed
    case codeChanged(String)
    case submitButtonTapped
  }

  public init(store: StoreOf<TwoFactor>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(
      self.store, observe: ViewState.init, send: TwoFactor.Action.init
    ) { viewStore in
      Form {
        Text(#"To confirm the second factor enter "1234" into the form."#)

        Section {
          TextField(
            "1234",
            text: viewStore.binding(get: \.code, send: ViewAction.codeChanged)
          )
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
      .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
      .disabled(viewStore.isFormDisabled)
      .navigationTitle("Confirmation Code")
    }
  }
}

extension TwoFactor.Action {
  init(action: TwoFactorView.ViewAction) {
    switch action {
    case .alertDismissed:
      self = .alertDismissed
    case let .codeChanged(code):
      self = .codeChanged(code)
    case .submitButtonTapped:
      self = .submitButtonTapped
    }
  }
}

struct TwoFactorView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      TwoFactorView(
        store: Store(
          initialState: TwoFactor.State(token: "deadbeef"),
          reducer: TwoFactor()
        ) {
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
