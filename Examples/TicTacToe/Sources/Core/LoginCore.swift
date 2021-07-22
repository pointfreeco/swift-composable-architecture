import AuthenticationClient
import ComposableArchitecture
import Dispatch
import TicTacToeCommon
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
  case loginResponse(Result<AuthenticationResponse, AuthenticationError>)
  case twoFactor(PresentationAction<TwoFactorAction>)
}

public struct LoginEnvironment {
  public var authenticationClient: AuthenticationClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    authenticationClient: AuthenticationClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.authenticationClient = authenticationClient
    self.mainQueue = mainQueue
  }
}

public let loginReducer = Reducer<
  LoginState,
  LoginAction,
  LoginEnvironment
> {
  state, action, environment in
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

  case .twoFactor(.present):
    state.isLoginRequestInFlight = true
    return environment.authenticationClient
      .login(LoginRequest(email: state.email, password: state.password))
      .receive(on: environment.mainQueue)
      .catchToEffect()
      .map(LoginAction.loginResponse)

  case .twoFactor:
    return .none
  }
}
.navigates(
  destination: twoFactorReducer,
  state: \.twoFactor,
  action: /LoginAction.twoFactor,
  environment: {
    TwoFactorEnvironment(
      authenticationClient: $0.authenticationClient,
      mainQueue: $0.mainQueue
    )
  }
)
