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

    public init(token: String) {
      self.token = token
    }
  }

  public enum Action: Equatable {
    case alertDismissed
    case codeChanged(String)
    case submitButtonTapped
    case twoFactorResponse(Result<AuthenticationResponse, AuthenticationError>)
  }

  public enum TearDownToken {}

  @Dependency(\.authenticationClient) var authenticationClient
  @Dependency(\.mainQueue) var mainQueue

  public init() {}

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
      return self.authenticationClient
        .twoFactor(TwoFactorRequest(code: state.code, token: state.token))
        .receive(on: self.mainQueue)
        .catchToEffect(Action.twoFactorResponse)
        .cancellable(id: TearDownToken.self)

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
