import ComposableArchitecture
import GameCore

public struct NewGame: Reducer {
  @ObservableState
  public struct State: Equatable {
    @ObservationStateIgnored
    @PresentationState public var game: Game.State?
    public var oPlayerName = ""
    public var xPlayerName = ""

    public init() {}
  }

  public enum Action: Equatable, ViewAction {
    case game(PresentationAction<Game.Action>)
    case view(View)

    public enum View: Equatable {
      case letsPlayButtonTapped
      case logoutButtonTapped
      case oPlayerNameChanged(String)
      case xPlayerNameChanged(String)
    }
  }

  public init() {}

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .game:
        return .none

      case .view(.letsPlayButtonTapped):
        state.game = Game.State(
          oPlayerName: state.oPlayerName,
          xPlayerName: state.xPlayerName
        )
        return .none

      case .view(.logoutButtonTapped):
        return .none

      case let .view(.oPlayerNameChanged(name)):
        state.oPlayerName = name
        return .none

      case let .view(.xPlayerNameChanged(name)):
        state.xPlayerName = name
        return .none
      }
    }
    .ifLet(\.$game, action: /NewGame.Action.game) {
      Game()
    }
  }
}
