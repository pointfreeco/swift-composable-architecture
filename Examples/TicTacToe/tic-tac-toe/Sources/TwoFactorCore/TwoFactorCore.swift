import AuthenticationClient
import Combine
import ComposableArchitecture
import Dispatch

public struct TwoFactor: ReducerProtocol, Sendable {
  public struct State: Equatable {
    @PresentationState public var alert: AlertState<Action.Alert>?
    @BindingState public var code = ""
    public var isFormValid = false
    public var isTwoFactorRequestInFlight = false
    public let token: String

    public init(token: String) {
      self.token = token
    }
  }

  public enum Action: Equatable {
    case alert(PresentationAction<Alert>)
    case twoFactorResponse(TaskResult<AuthenticationResponse>)
    case view(View)

    public enum Alert: Equatable {}

    public enum View: BindableAction, Equatable {
      case binding(BindingAction<State>)
      case submitButtonTapped
    }
  }

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer(action: /Action.view)
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case let .twoFactorResponse(.failure(error)):
        state.alert = AlertState { TextState(error.localizedDescription) }
        state.isTwoFactorRequestInFlight = false
        return .none

      case .twoFactorResponse(.success):
        state.isTwoFactorRequestInFlight = false
        return .none

      case .view(.binding):
        state.isFormValid = state.code.count >= 4
        return .none

      case .view(.submitButtonTapped):
        state.isTwoFactorRequestInFlight = true
        return .task { [code = state.code, token = state.token] in
          .twoFactorResponse(
            await TaskResult {
              try await self.authenticationClient.twoFactor(.init(code: code, token: token))
            }
          )
        }
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
  }
}
