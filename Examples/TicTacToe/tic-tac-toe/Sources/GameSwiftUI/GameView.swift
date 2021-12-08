import ComposableArchitecture
import GameCore
import SwiftUI

public struct GameView: View {
  let store: Store<GameState, GameAction>
  @ObservedObject var viewStore: ViewStore<ViewState, GameAction>

  struct ViewState: Equatable {
    var board: [[String]]
    var isGameDisabled: Bool
    var isPlayAgainButtonVisible: Bool
    var title: String

    init(state: GameState) {
      self.board = state.board.map { $0.map { $0?.label ?? "" } }
      self.isGameDisabled = state.board.hasWinner || state.board.isFilled
      self.isPlayAgainButtonVisible = state.board.hasWinner || state.board.isFilled
      self.title =
      state.board.hasWinner
      ? "Winner! Congrats \(state.currentPlayerName)!"
      : state.board.isFilled
      ? "Tied game!"
      : "\(state.currentPlayerName), place your \(state.currentPlayer.label)"
    }
  }

  public init(store: Store<GameState, GameAction>) {
    self.store = store
    self.viewStore = ViewStore(store.scope(state: ViewState.init))
  }

  public var body: some View {
    GeometryReader { proxy in
      VStack(spacing: 0.0) {
        VStack {
          Text(self.viewStore.title)
            .font(Font.title)

          if self.viewStore.isPlayAgainButtonVisible {
            Button("Play again?") {
              self.viewStore.send(.playAgainButtonTapped)
            }
            .padding([.top], 12)
            .font(Font.title)
          }
        }
        .padding([.bottom], 48)

        VStack {
          self.rowView(row: 0, proxy: proxy)
          self.rowView(row: 1, proxy: proxy)
          self.rowView(row: 2, proxy: proxy)
        }
        .disabled(self.viewStore.isGameDisabled)
      }
      .navigationBarTitle("Tic-tac-toe")
      .navigationBarItems(leading: Button("Quit") { self.viewStore.send(.quitButtonTapped) })
      .navigationBarBackButtonHidden(true)
    }
  }

  func rowView(
    row: Int,
    proxy: GeometryProxy
  ) -> some View {
    HStack(spacing: 0.0) {
      self.cellView(row: row, column: 0, proxy: proxy)
      self.cellView(row: row, column: 1, proxy: proxy)
      self.cellView(row: row, column: 2, proxy: proxy)
    }
  }

  func cellView(
    row: Int,
    column: Int,
    proxy: GeometryProxy
  ) -> some View {
    Button(action: {
      self.viewStore.send(.cellTapped(row: row, column: column))
    }) {
      Text(self.viewStore.board[row][column])
        .frame(width: proxy.size.width / 3, height: proxy.size.width / 3)
        .background(
          (row + column).isMultiple(of: 2)
          ? Color(red: 0.8, green: 0.8, blue: 0.8)
          : Color(red: 0.6, green: 0.6, blue: 0.6)
        )
    }
  }
}

struct Game_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      GameView(
        store: Store(
          initialState: GameState(oPlayerName: "Blob Jr.", xPlayerName: "Blob Sr."),
          reducer: gameReducer,
          environment: GameEnvironment()
        )
      )
    }
  }
}
