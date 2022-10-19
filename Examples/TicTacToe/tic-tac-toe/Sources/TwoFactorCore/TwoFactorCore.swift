import AuthenticationClient
import Combine
import ComposableArchitecture
import Dispatch

public struct TwoFactor: ReducerProtocol, Sendable {
  public struct State: Equatable {
    public var alert: AlertState<Action>?
    public var code = ""
    public var isFormValid = false
    public var isTwoFactorRequestInFlight = false
    public let token: String

    public init(token: String) {
      self.token = token
    }
  }

  public enum Action: Equatable {
    case alertDismissed
    case codeChanged(String)
    case submitButtonTapped
    case twoFactorResponse(TaskResult<AuthenticationResponse>)
  }

  public enum TearDownToken {}

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .alertDismissed:
      state.alert = nil
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
      .cancellable(id: TearDownToken.self)

    case let .twoFactorResponse(.failure(error)):
      state.alert = AlertState(title: TextState(error.localizedDescription))
      state.isTwoFactorRequestInFlight = false
      return .none

    case .twoFactorResponse(.success):
      state.isTwoFactorRequestInFlight = false
      return .none
    }
  }
}
