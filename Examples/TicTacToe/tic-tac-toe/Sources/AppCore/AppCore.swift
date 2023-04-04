import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore

public struct TicTacToe: ReducerProtocol {
  public enum State: Equatable {
    case login(Login.State)
    case newGame(NewGame.State)

    public init() { self = .login(Login.State()) }
  }

  public enum Action: Equatable {
    case login(Login.Action)
    case newGame(NewGame.Action)
  }

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .login(.twoFactor(.twoFactorResponse(.success))):
        state = .newGame(NewGame.State())
        return nil

      case let .login(.loginResponse(.success(response))) where !response.twoFactorRequired:
        state = .newGame(NewGame.State())
        return nil

      case .login:
        return nil

      case .newGame(.logoutButtonTapped):
        state = .login(Login.State())
        return nil

      case .newGame:
        return nil
      }
    }
    .ifCaseLet(/State.login, action: /Action.login) {
      Login()
    }
    .ifCaseLet(/State.newGame, action: /Action.newGame) {
      NewGame()
    }
  }
}
