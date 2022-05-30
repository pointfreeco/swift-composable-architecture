import AuthenticationClient
import ComposableArchitecture
import SwiftUI
import TwoFactorCore

public struct TwoFactorView: View {
  let store: Store<TwoFactorState, TwoFactorAction>

  struct ViewState: Equatable {
    var alert: AlertState<TwoFactorAction>?
    var code: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isSubmitButtonDisabled: Bool

    init(state: TwoFactorState) {
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

  public init(store: Store<TwoFactorState, TwoFactorAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(
      self.store.scope(state: ViewState.init, action: TwoFactorAction.init)
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
      .navigationBarTitle("Confirmation Code")
    }
  }
}

extension TwoFactorAction {
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
          initialState: TwoFactorState(token: "deadbeef"),
          reducer: twoFactorReducer,
          environment: TwoFactorEnvironment(
            authenticationClient: AuthenticationClient(
              login: { _ in Effect(value: .init(token: "deadbeef", twoFactorRequired: false)) },
              twoFactor: { _ in
                Effect(value: .init(token: "deadbeef", twoFactorRequired: false))
              }
            ),
            mainQueue: .main
          )
        )
      )
    }
  }
}
