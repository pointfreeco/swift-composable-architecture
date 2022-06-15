import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore
import TwoFactorCore
import GameCore

public struct AppReducer: ReducerProtocol {
  @Dependency(\.navigationID.next) var nextID

  public init() {
  }

  public struct State: Hashable, NavigableState {
    public var login: Login.State
    public var path: NavigationState<Route>

    public init(
      login: Login.State = .init(),
      path: NavigationState<Route> = []
    ) {
      self.login = login
      self.path = path
    }

    public enum Route: Hashable {
      case twoFactor(TwoFactor.State)
      case newGame(NewGame.State)
      case game(Game.State)
    }
  }

  public enum Action: Hashable, NavigableAction {
    case login(Login.Action)
    // TODO: NavigationActionOf<_AppReducer> ?
    case navigation(NavigationAction<State.Route, Route>)

    public enum Route: Hashable {
      case twoFactor(TwoFactor.Action)
      case newGame(NewGame.Action)
      case game(Game.Action)
    }
  }

  public var body: some ReducerProtocol<State, Action> {
    Pullback(state: \State.login, action: CasePath(Action.login)) {
      Login()
    }

    Reduce { state, action in
      switch action {
      case let .login(.loginResponse(.success(response))):
        if response.twoFactorRequired {
          state.path = [.init(id: self.nextID(), element: .twoFactor(.init(token: response.token)))]
        } else {
          state.path = [.init(id: self.nextID(), element: .newGame(.init()))]
        }
        return .none

      case .login:
        return .none

      case .navigation(.element(id: _, .twoFactor(.twoFactorResponse(.success)))):
        state.path = [.init(id: self.nextID(), element: .newGame(.init()))]
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

        // TODO: replace with dismiss environment?
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
      PullbackCase(state: CasePath(State.Route.twoFactor), action: CasePath(Action.Route.twoFactor)) {
        TwoFactor()
      }
    }
    .navigationDestination {
      PullbackCase(state: CasePath(State.Route.newGame), action: CasePath(Action.Route.newGame)) {
        NewGame()
      }
    }
    .navigationDestination {
      PullbackCase(state: CasePath(State.Route.game), action: CasePath(Action.Route.game)) {
        Game()
      }
    }
  }
}

//public struct AppReducer: ReducerProtocol {
//  public enum State: Equatable {
//    case login(Login.State)
//    case newGame(NewGame.State)
//
//    public init() { self = .login(.init()) }
//  }
//
//  public enum Action: Equatable {
//    case login(Login.Action)
//    case newGame(NewGame.Action)
//  }
//
//  public init() {}
//
//  public var body: some ReducerProtocol<State, Action> {
//    PullbackCase(state: /State.login, action: /Action.login) {
//      Login()
//    }
//
//    PullbackCase(state: /State.newGame, action: /Action.newGame) {
//      NewGame()
//    }
//
//    Reduce { state, action in
//      switch action {
//      case .login(.twoFactor(.twoFactorResponse(.success))):
//        state = .newGame(.init())
//        return .none
//
//      case let .login(.loginResponse(.success(response))) where !response.twoFactorRequired:
//        state = .newGame(.init())
//        return .none
//
//      case .login:
//        return .none
//
//      case .newGame(.logoutButtonTapped):
//        state = .login(.init())
//        return .none
//
//      case .newGame:
//        return .none
//      }
//    }
//  }
//}
