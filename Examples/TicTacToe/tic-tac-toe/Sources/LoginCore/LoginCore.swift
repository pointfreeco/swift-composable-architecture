import AuthenticationClient
import ComposableArchitecture
import Dispatch
import TwoFactorCore

public struct LoginState: Equatable {
  public var alert: AlertState<LoginAction>?
  public var email = ""
  public var isFormValid = false
  public var isLoginRequestInFlight = false
  public var password = ""
  public var twoFactor: TwoFactorState?

  public init() {}
}

public enum LoginAction: Equatable {
  case alertDismissed
  case emailChanged(String)
  case passwordChanged(String)
  case loginButtonTapped
  case loginResponse(Result<AuthenticationResponse, AuthenticationError>)
  case twoFactor(TwoFactorAction)
  case twoFactorDismissed
}

public struct LoginReducer: ReducerProtocol {
  @Dependency(\.authenticationClient) var authenticationClient
  @Dependency(\.mainQueue) var mainQueue

  public init() {}

  public var body: some ReducerProtocol<LoginState, LoginAction> {
    Pullback(state: \.twoFactor, action: /LoginAction.twoFactor) {
      IfLetReducer {
        TwoFactorReducer()
      }
    }

    Reduce { state, action in
      switch action {
      case .alertDismissed:
        state.alert = nil
        return .none

      case let .emailChanged(email):
        state.email = email
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
        return .none

      case let .loginResponse(.success(response)):
        state.isLoginRequestInFlight = false
        if response.twoFactorRequired {
          state.twoFactor = TwoFactorState(token: response.token)
        }
        return .none

      case let .loginResponse(.failure(error)):
        state.alert = .init(title: TextState(error.localizedDescription))
        state.isLoginRequestInFlight = false
        return .none

      case let .passwordChanged(password):
        state.password = password
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
        return .none

      case .loginButtonTapped:
        state.isLoginRequestInFlight = true
        return self.authenticationClient
          .login(LoginRequest(email: state.email, password: state.password))
          .receive(on: self.mainQueue)
          .catchToEffect(LoginAction.loginResponse)

      case .twoFactor:
        return .none

      case .twoFactorDismissed:
        state.twoFactor = nil
        return .cancel(id: TwoFactorReducer.TearDownToken.self)
      }
    }
  }
}
