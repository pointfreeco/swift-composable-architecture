import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore

public struct AppReducer: ReducerProtocol {
  public enum State: Equatable {
    case login(Login.State)
    case newGame(NewGame.State)

    public init() { self = .login(.init()) }
  }

  public enum Action: Equatable {
    case login(Login.Action)
    case newGame(NewGame.Action)
  }

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    ScopeCase(state: /State.login, action: /Action.login) {
      Login()
    }

    ScopeCase(state: /State.newGame, action: /Action.newGame) {
      NewGame()
    }

    Reduce { state, action in
      switch action {
      case .login(.twoFactor(.twoFactorResponse(.success))):
        state = .newGame(.init())
        return .none

      case let .login(.loginResponse(.success(response))) where !response.twoFactorRequired:
        state = .newGame(.init())
        return .none

      case .login:
        return .none

      case .newGame(.logoutButtonTapped):
        state = .login(.init())
        return .none

      case .newGame:
        return .none
      }
    }
  }
}
