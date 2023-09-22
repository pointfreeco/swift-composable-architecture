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

    public var isLetsPlayButtonEnabled: Bool {
      !self.oPlayerName.isEmpty && !self.xPlayerName.isEmpty
    }
  }

  @CasePathable
  public enum Action: Equatable, ViewAction {
    case delegate(Delegate)
    case game(PresentationAction<Game.Action>)
    case view(View)

    public enum Delegate: Equatable {
      case logout
    }

    public enum View: BindableAction, Equatable {
      case binding(BindingAction<State>)
      case letsPlayButtonTapped
      case logoutButtonTapped
    }
  }

  public init() {}

  public var body: some Reducer<State, Action> {
    CombineReducers {
      BindingReducer()
      Reduce { state, action in
        switch action {
        case .delegate:
          return .none

        case .game:
          return .none

        case .view(.binding):
          return .none

        case .view(.logoutButtonTapped):
          return .send(.delegate(.logout))

        case .view(.letsPlayButtonTapped):
          state.game = Game.State(
            oPlayerName: state.oPlayerName,
            xPlayerName: state.xPlayerName
          )
          return .none
        }
      }
    }
    .ifLet(\.$game, action: #casePath(\.game)) {
      Game()
    }
  }
}
