import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore
import TwoFactorCore
import GameCore

struct _AppReducer: ReducerProtocol {
  @Dependency(\.navigationID.next) var nextID

  struct State: Hashable, NavigableState {
    var path: NavigationState<Route> = []

    enum Route: Hashable {
      case login(Login.State)
      case twoFactor(TwoFactor.State)
      case newGame(NewGame.State)
      case game(Game.State)
    }
  }

  enum Action: Hashable, NavigableAction {
    // TODO: NavigationActionOf<_AppReducer> ?
    case navigation(NavigationAction<State.Route, Route>)

    enum Route: Hashable {
      case login(Login.Action)
      case twoFactor(TwoFactor.Action)
      case newGame(NewGame.Action)
      case game(Game.Action)
    }
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .navigation(.element(id: _, .login(.loginResponse(.success(response)))))
        where !response.twoFactorRequired:

        state.path = [.init(id: self.nextID(), element: .login(.init()))]
        return .none

      case .navigation(.element(id: _, .twoFactor(.twoFactorResponse(.success)))):
        state.path = [.init(id: self.nextID(), element: .login(.init()))]
        return .none

      case let .navigation(.element(id: id, .newGame(.letsPlayButtonTapped))):
        let newGameState = CasePath(State.Route.newGame).extract(from: state.path[id: id]!)!
        state.path.append(
          .init(
            id: self.nextID(),
            element: .game(
              .init(
                oPlayerName: newGameState.oPlayerName,
                xPlayerName: newGameState.xPlayerName
              )
            )
          )
        )
        return .none

      case .navigation(.element(id: _, .newGame(.logoutButtonTapped))):
        state.path = state.path.dropLast()
        return .none

      case .navigation(.element(id: _, .game(.quitButtonTapped))):
        state.path = state.path.dropLast()
        return .none

      case .navigation:
        return .none
      }
    }
    .navigationDestination {
      PullbackCase(state: CasePath(State.Route.login), action: CasePath(Action.Route.login)) {
        Login()
      }
    }
  }
}

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
    PullbackCase(state: /State.login, action: /Action.login) {
      Login()
    }

    PullbackCase(state: /State.newGame, action: /Action.newGame) {
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
