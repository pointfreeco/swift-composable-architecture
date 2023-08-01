import AuthenticationClient
import Combine
import ComposableArchitecture
import Dispatch

public struct TwoFactor: Reducer, Sendable {
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

  public enum Action: Equatable, Sendable {
    case alert(PresentationAction<Alert>)
    case twoFactorResponse(TaskResult<AuthenticationResponse>)
    case view(View)

    public enum Alert: Equatable, Sendable {}

    public enum View: BindableAction, Equatable, Sendable {
      case binding(BindingAction<State>)
      case submitButtonTapped
    }
  }

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public var body: some ReducerOf<Self> {
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
        return .run { [code = state.code, token = state.token] send in
          await send(
            .twoFactorResponse(
              await TaskResult {
                try await self.authenticationClient.twoFactor(.init(code: code, token: token))
              }
            )
          )
        }
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
  }
}
