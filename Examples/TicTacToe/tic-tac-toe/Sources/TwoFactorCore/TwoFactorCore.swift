import AuthenticationClient
import Combine
import ComposableArchitecture
import Dispatch

public struct TwoFactor: ReducerProtocol, Sendable {
  public struct State: Equatable {
    public var alert: AlertState<Action>?
    @BindingState public var code = ""
    public var isFormValid = false
    public var isTwoFactorRequestInFlight = false
    public let token: String

    public init(token: String) {
      self.token = token
    }
  }

  public enum Action: Equatable {
    case alertDismissed
    case twoFactorResponse(TaskResult<AuthenticationResponse>)
    case view(ViewAction)
  }

  public enum ViewAction: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case submitButtonTapped
  }

  public enum TearDownToken {}

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer(action: /Action.view)
    Reduce { state, action in
      switch action {
      case .alertDismissed:
        state.alert = nil
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
        .cancellable(id: TearDownToken.self)

      case let .twoFactorResponse(.failure(error)):
        state.alert = AlertState { TextState(error.localizedDescription) }
        state.isTwoFactorRequestInFlight = false
        return .none

      case .twoFactorResponse(.success):
        state.isTwoFactorRequestInFlight = false
        return .none
      }
    }
  }
}
