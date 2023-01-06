import AuthenticationClient
import ComposableArchitecture
import Dispatch
import TwoFactorCore

public struct Login: ReducerProtocol, Sendable {
  public struct State: Equatable {
    public var alert: AlertState<Action>?
    @BindingState public var email = ""
    public var isFormValid = false
    public var isLoginRequestInFlight = false
    @BindingState public var password = ""
    public var twoFactor: TwoFactor.State?

    public init() {}
  }

  public enum Action: BindableAction, Equatable {
    case alertDismissed
    case binding(BindingAction<State>)
    case loginButtonTapped
    case loginResponse(TaskResult<AuthenticationResponse>)
    case twoFactor(TwoFactor.Action)
    case twoFactorDismissed
  }

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .alertDismissed:
        state.alert = nil
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
        return .task { [email = state.email, password = state.password] in
          .loginResponse(
            await TaskResult {
              try await self.authenticationClient.login(
                .init(email: email, password: password)
              )
            }
          )
        }

      case .twoFactor:
        return .none

      case .twoFactorDismissed:
        state.twoFactor = nil
        return .cancel(id: TwoFactor.TearDownToken.self)
      }
    }
    .ifLet(\.twoFactor, action: /Action.twoFactor) {
      TwoFactor()
    }
  }
}
