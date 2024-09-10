import AuthenticationClient
import ComposableArchitecture
import Dispatch
import TwoFactorCore

@Reducer
public struct Login: Sendable {
  @ObservableState
  public struct State: Equatable {
    @Presents public var alert: AlertState<Action.Alert>?
    public var email = ""
    public var isFormValid = false
    public var isLoginRequestInFlight = false
    public var password = ""
    @Presents public var twoFactor: TwoFactor.State?

    public init() {}
  }

  public enum Action: Sendable, ViewAction {
    case alert(PresentationAction<Alert>)
    case loginResponse(Result<AuthenticationResponse, any Error>)
    case twoFactor(PresentationAction<TwoFactor.Action>)
    case view(View)

    public enum Alert: Equatable, Sendable {}

    @CasePathable
    public enum View: BindableAction, Sendable {
      case binding(BindingAction<State>)
      case loginButtonTapped
    }
  }

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public var body: some Reducer<State, Action> {
    BindingReducer(action: \.view)
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case let .loginResponse(.success(response)):
        state.isLoginRequestInFlight = false
        if response.twoFactorRequired {
          state.twoFactor = TwoFactor.State(token: response.token)
        }
        return .none

      case let .loginResponse(.failure(error)):
        state.alert = AlertState { TextState(error.localizedDescription) }
        state.isLoginRequestInFlight = false
        return .none

      case .twoFactor:
        return .none

      case .view(.binding):
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
        return .none

      case .view(.loginButtonTapped):
        state.isLoginRequestInFlight = true
        return .run { [email = state.email, password = state.password] send in
          await send(
            .loginResponse(
              Result {
                try await self.authenticationClient.login(email: email, password: password)
              }
            )
          )
        }
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.$twoFactor, action: \.twoFactor) {
      TwoFactor()
    }
  }
}
