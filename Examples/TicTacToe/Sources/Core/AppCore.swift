import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore

public enum AppState: Equatable {
  case login(LoginState)
  case newGame(NewGameState)

  public init() {
    self = .login(.init())
  }
}

//public struct AppState: Equatable {
//  public var login: LoginState? = LoginState()
//  public var newGame: NewGameState?
//
//  public init() {}
//}

public enum AppAction: Equatable {
  case login(LoginAction)
  case newGame(NewGameAction)
}

public struct AppEnvironment {
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

extension Reducer {
  func pullback<GlobalState, GlobalAction, GlobalEnvironment>(
    state toLocalState: CasePath<GlobalState, State>,
    action toLocalAction: CasePath<GlobalAction, Action>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let localAction = toLocalAction.extract(from: globalAction)
      else { return .none }

      guard var localState = toLocalState.extract(from: globalState)
      else { return .none }

      let effects = self.run(
        &localState,
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map(toLocalAction.embed)

      globalState = toLocalState.embed(localState)

      return effects
    }
  }
}

public let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  loginReducer
//    .optional()
    .pullback(
      state: /AppState.login,
      action: /AppAction.login,
      environment: {
        LoginEnvironment(
          authenticationClient: $0.authenticationClient,
          mainQueue: $0.mainQueue
        )
      }
    ),

  newGameReducer
//    .optional()
    .pullback(
      state: /AppState.newGame,
      action: /AppAction.newGame,
      environment: { _ in NewGameEnvironment() }
    ),

  Reducer { state, action, _ in
    switch action {
    case let .login(.twoFactor(.twoFactorResponse(.success(response)))),
      let .login(.loginResponse(.success(response))) where !response.twoFactorRequired:
      state = .newGame(.init())
//      state.newGame = NewGameState()
//      state.login = nil
      return .none

    case .login:
      return .none

    case .newGame(.logoutButtonTapped):
//      state.newGame = nil
//      state.login = LoginState()
      state = .login(.init())
      return .none

    case .newGame:
      return .none
    }
  }
)
