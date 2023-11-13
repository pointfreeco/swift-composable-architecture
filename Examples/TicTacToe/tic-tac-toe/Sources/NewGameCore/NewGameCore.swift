import ComposableArchitecture
import GameCore

@Reducer
public struct NewGame {
  public struct State: Equatable {
    @PresentationState public var game: Game.State?
    public var oPlayerName = ""
    public var xPlayerName = ""

    public init() {}
  }

  public enum Action {
    case game(PresentationAction<Game.Action>)
    case letsPlayButtonTapped
    case logoutButtonTapped
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
  }

  public init() {}

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .game:
        return .none

      case .letsPlayButtonTapped:
        state.game = Game.State(
          oPlayerName: state.oPlayerName,
          xPlayerName: state.xPlayerName
        )
        return .none

      case .logoutButtonTapped:
        return .none

      case let .oPlayerNameChanged(name):
        state.oPlayerName = name
        return .none

      case let .xPlayerNameChanged(name):
        state.xPlayerName = name
        return .none
      }
    }
    .ifLet(\.$game, action: \.game) {
      Game()
    }
  }
}
