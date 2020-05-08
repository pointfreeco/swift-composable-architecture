import ComposableArchitecture
import GameCore
import SwiftUI

public struct GameView: View {
  struct ViewState: Equatable {
    var board: [[String]]
    var isGameDisabled: Bool
    var isPlayAgainButtonVisible: Bool
    var title: String
  }

  let store: Store<GameState, GameAction>

  public init(store: Store<GameState, GameAction>) {
    self.store = store
  }

  public var body: some View {
    GeometryReader { proxy in
      WithViewStore(self.store.scope(state: { $0.view })) { viewStore in
        VStack(spacing: 0.0) {
          VStack {
            Text(viewStore.title)
              .font(Font.title)

            if viewStore.isPlayAgainButtonVisible {
              Button("Play again?") {
                viewStore.send(.playAgainButtonTapped)
              }
              .padding([.top], 12)
              .font(Font.title)
            }
          }
          .padding([.bottom], 48)

          VStack {
            self.rowView(row: 0, proxy: proxy, viewStore: viewStore)
            self.rowView(row: 1, proxy: proxy, viewStore: viewStore)
            self.rowView(row: 2, proxy: proxy, viewStore: viewStore)
          }
          .disabled(viewStore.isGameDisabled)
        }
        .navigationBarTitle("Tic-tac-toe")
        .navigationBarItems(leading: Button("Quit") { viewStore.send(.quitButtonTapped) })
        .navigationBarBackButtonHidden(true)
      }
    }
  }

  func rowView(
    row: Int,
    proxy: GeometryProxy,
    viewStore: ViewStore<ViewState, GameAction>
  ) -> some View {
    HStack(spacing: 0.0) {
      self.cellView(row: row, column: 0, proxy: proxy, viewStore: viewStore)
      self.cellView(row: row, column: 1, proxy: proxy, viewStore: viewStore)
      self.cellView(row: row, column: 2, proxy: proxy, viewStore: viewStore)
    }
  }

  func cellView(
    row: Int,
    column: Int,
    proxy: GeometryProxy,
    viewStore: ViewStore<ViewState, GameAction>
  ) -> some View {
    Button.init(action: {
      viewStore.send(.cellTapped(row: row, column: column))
    }) {
      Text(viewStore.board[row][column])
        .frame(width: proxy.size.width / 3, height: proxy.size.width / 3)
        .background(
          (row + column).isMultiple(of: 2)
            ? Color(red: 0.8, green: 0.8, blue: 0.8)
            : Color(red: 0.6, green: 0.6, blue: 0.6)
        )
    }
  }
}

extension GameState {
  var view: GameView.ViewState {
    GameView.ViewState(
      board: self.board.map { $0.map { $0?.label ?? "" } },
      isGameDisabled: self.board.hasWinner || self.board.isFilled,
      isPlayAgainButtonVisible: self.board.hasWinner || self.board.isFilled,
      title: self.board.hasWinner
        ? "Winner! Congrats \(self.currentPlayerName)!"
        : self.board.isFilled
          ? "Tied game!"
          : "\(self.currentPlayerName), place your \(self.currentPlayer.label)"
    )
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
