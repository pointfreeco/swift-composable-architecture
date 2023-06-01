import AuthenticationClient
import ComposableArchitecture
import Dispatch
import TwoFactorCore

public struct Login: ReducerProtocol, Sendable {
  public struct State: Equatable {
    @PresentationState public var alert: AlertState<AlertAction>?
    @BindingState public var email = ""
    public var isFormValid = false
    public var isLoginRequestInFlight = false
    @BindingState public var password = ""
    @PresentationState public var twoFactor: TwoFactor.State?

    public init() {}
  }

  public enum Action: BindableAction, Equatable {
    case alert(PresentationAction<AlertAction>)
    case binding(BindingAction<State>)
    case loginButtonTapped
    case loginResponse(TaskResult<AuthenticationResponse>)
    case twoFactor(PresentationAction<TwoFactor.Action>)
  }

  public enum AlertAction: Equatable, Sendable {}

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case .binding:
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
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

      case .loginButtonTapped:
        state.isLoginRequestInFlight = true
        return .run { [email = state.email, password = state.password] send in
          await send(
            .loginResponse(
              await TaskResult {
                try await self.authenticationClient.login(
                  .init(email: email, password: password)
                )
              }
            )
          )
        }

      case .twoFactor:
        return .none
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
    .ifLet(\.$twoFactor, action: /Action.twoFactor) {
      TwoFactor()
    }
  }
}
