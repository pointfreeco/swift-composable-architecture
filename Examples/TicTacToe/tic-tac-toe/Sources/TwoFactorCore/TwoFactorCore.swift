import AuthenticationClient
import Combine
import ComposableArchitecture
import Dispatch

public struct TwoFactor: ReducerProtocol, Sendable {
  public struct State: Equatable {
    @PresentationState public var alert: AlertState<Never>?
    @BindingState public var code = ""
    public var isFormValid = false
    public var isTwoFactorRequestInFlight = false
    public let token: String

    public init(token: String) {
      self.token = token
    }
  }

  public enum Action: BindableAction, Equatable {
    case alert(PresentationAction<Never>)
    case binding(BindingAction<State>)
    case submitButtonTapped
    case twoFactorResponse(TaskResult<AuthenticationResponse>)
  }

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case .binding:
        state.isFormValid = state.code.count >= 4
        return .none

      case .submitButtonTapped:
        state.isTwoFactorRequestInFlight = true
        return .task { [code = state.code, token = state.token] in
          .twoFactorResponse(
            await TaskResult {
              try await self.authenticationClient.twoFactor(.init(code: code, token: token))
            }
          )
        }

      case let .twoFactorResponse(.failure(error)):
        state.alert = AlertState { TextState(error.localizedDescription) }
        state.isTwoFactorRequestInFlight = false
        return .none

      case .twoFactorResponse(.success):
        state.isTwoFactorRequestInFlight = false
        return .none
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
  }
}
