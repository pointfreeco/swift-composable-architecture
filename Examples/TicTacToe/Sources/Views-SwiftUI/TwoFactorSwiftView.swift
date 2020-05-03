import AuthenticationClient
import ComposableArchitecture
import SwiftUI
import TicTacToeCommon
import TwoFactorCore

public struct TwoFactorView: View {
  struct ViewState: Equatable {
    var alertData: AlertData?
    var code: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isSubmitButtonDisabled: Bool
  }

  enum ViewAction {
    case alertDismissed
    case codeChanged(String)
    case submitButtonTapped
  }

  let store: Store<TwoFactorState, TwoFactorAction>

  public init(store: Store<TwoFactorState, TwoFactorAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: \.view, action: TwoFactorAction.view)) { viewStore in
      Form {
        Section(
          header: Text(#"To confirm the second factor enter "1234" into the form."#)
        ) {
          EmptyView()
        }

        Section(header: Text("Code")) {
          TextField(
            "1234",
            text: viewStore.binding(get: \.code, send: ViewAction.codeChanged)
          )
          .keyboardType(.numberPad)
        }

        Section {
          HStack {
            Button("Submit") {
              viewStore.send(.submitButtonTapped)
            }
            .disabled(viewStore.isSubmitButtonDisabled)

            if viewStore.isActivityIndicatorVisible {
              ActivityIndicator()
            }
          }
        }
      }
      .disabled(viewStore.isFormDisabled)
      .navigationBarTitle("Two Factor Confirmation")
      .alert(
        item: viewStore.binding(get: \.alertData, send: .alertDismissed)
      ) { alertData in
        Alert(title: Text(alertData.title))
      }
    }
  }
}

extension TwoFactorState {
  var view: TwoFactorView.ViewState {
    TwoFactorView.ViewState(
      alertData: self.alertData,
      code: self.code,
      isActivityIndicatorVisible: self.isTwoFactorRequestInFlight,
      isFormDisabled: self.isTwoFactorRequestInFlight,
      isSubmitButtonDisabled: !self.isFormValid
    )
  }
}

extension TwoFactorAction {
  static func view(_ localAction: TwoFactorView.ViewAction) -> Self {
    switch localAction {
    case .alertDismissed:
      return .alertDismissed
    case let .codeChanged(code):
      return .codeChanged(code)
    case .submitButtonTapped:
      return .submitButtonTapped
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
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
  }
}
