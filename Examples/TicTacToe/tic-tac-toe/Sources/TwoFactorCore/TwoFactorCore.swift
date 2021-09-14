import AuthenticationClient
import Combine
import ComposableArchitecture
import Dispatch

public struct TwoFactorState: Equatable {
  public var alert: AlertState<TwoFactorAction>?
  public var code = ""
  public var isFormValid = false
  public var isTwoFactorRequestInFlight = false
  public let token: String

  public init(token: String) {
    self.token = token
  }
}

public enum TwoFactorAction: Equatable {
  case alertDismissed
  case codeChanged(String)
  case submitButtonTapped
  case twoFactorResponse(Result<AuthenticationResponse, AuthenticationError>)
}

public struct TwoFactorTearDownToken: Hashable {
  public init() {}
}

public struct TwoFactorReducer: _Reducer {
  @Dependency(\.authenticationClient) var authenticationClient
  @Dependency(\.mainQueue) var mainQueue

  public static let main = Self()

  public func reduce(
    into state: inout TwoFactorState,
    action: TwoFactorAction
  ) -> Effect<TwoFactorAction, Never> {
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
      return self.authenticationClient
        .twoFactor(TwoFactorRequest(code: state.code, token: state.token))
        .receive(on: self.mainQueue)
        .catchToEffect(TwoFactorAction.twoFactorResponse)
        .cancellable(id: TwoFactorTearDownToken())

    case let .twoFactorResponse(.failure(error)):
      state.alert = .init(title: TextState(error.localizedDescription))
      state.isTwoFactorRequestInFlight = false
      return .none

    case .twoFactorResponse(.success):
      state.isTwoFactorRequestInFlight = false
      return .none
    }
  }
}
