import AuthenticationClient
import Combine
import ComposableArchitecture
import Dispatch

public struct TwoFactor: ReducerProtocol {
  public struct State: Equatable {
    public var alert: AlertState<Action>?
    public var code = ""
    public var isFormValid = false
    public var isTwoFactorRequestInFlight = false
    public let token: String

    public init(
      alert: AlertState<Action>? = nil,
      code: String = "",
      isFormValid: Bool = false,
      isTwoFactorRequestInFlight: Bool = false,
      token: String
    ) {
      self.alert = alert
      self.code = code
      self.isFormValid = isFormValid
      self.isTwoFactorRequestInFlight = isTwoFactorRequestInFlight
      self.token = token
    }
  }

  public enum Action: Equatable {
    case alertDismissed
    case codeChanged(String)
    case submitButtonTapped
    case twoFactorResponse(TaskResult<AuthenticationResponse>)
  }

  @Dependency(\.authenticationClient) var authenticationClient
  @Dependency(\.mainQueue) var mainQueue

  let tearDownToken: Any.Type

  public init(tearDownToken: Any.Type) {
    self.tearDownToken = tearDownToken
  }

  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
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
            try await self.authenticationClient.twoFactor(
              TwoFactorRequest(code: code, token: token)
            )
          }
        )
      }
      .cancellable(id: self.tearDownToken)

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
