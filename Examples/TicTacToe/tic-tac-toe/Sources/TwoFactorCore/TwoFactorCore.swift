import AuthenticationClient
import Combine
import ComposableArchitecture
import Dispatch

public struct TwoFactor: Reducer, Sendable {
  public struct State: Equatable {
    @PresentationState public var alert: AlertState<Never>?
    public var code = ""
    public var isFormValid = false
    public var isTwoFactorRequestInFlight = false
    public let token: String

    public init(token: String) {
      self.token = token
    }
  }

  public enum Action: Equatable {
    case alert(PresentationAction<Never>)
    case codeChanged(String)
    case submitButtonTapped
    case twoFactorResponse(TaskResult<AuthenticationResponse>)
  }

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public var body: some ReducerProtocolOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .alert:
        return .none

      case let .codeChanged(code):
        state.code = code
        state.isFormValid = code.count >= 4
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
