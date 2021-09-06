import AuthenticationClient
import ComposableArchitecture
import Dispatch
import TwoFactorCore

public struct LoginState: Equatable {
  public var alert: AlertState<LoginAction>?
  @BindableState public var email = ""
  public var isFormValid = false
  public var isLoginRequestInFlight = false
  @BindableState public var password = ""
  public var twoFactor: TwoFactorState?

  public init() {}
}

public enum LoginAction: BindableAction, Equatable {
  case alertDismissed
  case binding(BindingAction<LoginState>)
  case loginButtonTapped
  case loginResponse(Result<AuthenticationResponse, AuthenticationError>)
  case twoFactor(TwoFactorAction)
  case twoFactorDismissed
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

public let loginReducer = Reducer<LoginState, LoginAction, LoginEnvironment>.combine(
  twoFactorReducer
    .optional()
    .pullback(
      state: \.twoFactor,
      action: /LoginAction.twoFactor,
      environment: {
        TwoFactorEnvironment(
          authenticationClient: $0.authenticationClient,
          mainQueue: $0.mainQueue
        )
      }
    ),

  .init {
    state, action, environment in
    switch action {
    case .alertDismissed:
      state.alert = nil
      return .none

    case .binding:
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

    case .loginButtonTapped:
      state.isLoginRequestInFlight = true
      return environment.authenticationClient
        .login(LoginRequest(email: state.email, password: state.password))
        .receive(on: environment.mainQueue)
        .catchToEffect(LoginAction.loginResponse)

    case .twoFactor:
      return .none

    case .twoFactorDismissed:
      state.twoFactor = nil
      return .cancel(id: TwoFactorTearDownToken())
    }
  }
    .binding()
)
