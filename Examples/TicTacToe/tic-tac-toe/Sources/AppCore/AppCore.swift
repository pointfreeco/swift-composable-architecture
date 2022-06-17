import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore
import TwoFactorCore
import GameCore

public struct AppReducer: ReducerProtocol {
  @Dependency(\.navigationID.next) var nextID

  public init() {}

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

    // TODO: Rename Destination?
    public enum Route: Hashable {
      case twoFactor(TwoFactor.State)
      case newGame(NewGame.State)
      case game(Game.State)
    }
  }

  public enum Action: Hashable, NavigableAction {
    // TODO: why are these needed??
    public typealias DestinationState = State.Route
    public typealias DestinationAction = Route

    case login(Login.Action)
    // TODO: can we get this to work without the typealiases above??
    case navigation(NavigationActionOf<AppReducer>)
//    case navigation(NavigationAction<State.Route, Route>)

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

    self.core
      .navigationDestination { self.destinations }
  }

  var core: some ReducerProtocol<State, Action> {
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

      case .navigation:
        return .none
      }
    }
  }

  @ReducerBuilder<State.Route, Action.Route>
  var destinations: some ReducerProtocol<State.Route, Action.Route> {
    PullbackCase(
      state: CasePath(State.Route.twoFactor),
      action: CasePath(Action.Route.twoFactor)
    ) {
      TwoFactor()
    }
    PullbackCase(
      state: CasePath(State.Route.newGame),
      action: CasePath(Action.Route.newGame)
    ) {
      NewGame()
    }
    PullbackCase(
      state: CasePath(State.Route.game),
      action: CasePath(Action.Route.game)
    ) {
      Game()
    }
  }
}
