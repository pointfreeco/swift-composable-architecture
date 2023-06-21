import ComposableArchitecture
import GameCore
import SwiftUI

public struct GameView: View {
  let store: StoreOf<Game>

  struct ViewState: Equatable, Sendable {
    var board: [[String]]
    var isGameDisabled: Bool
    var isPlayAgainButtonVisible: Bool
    var title: String

    init(state: Game.State) {
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

  public init(store: StoreOf<Game>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store, observe: ViewState.init) { viewStore in
      GeometryReader { proxy in
        VStack(spacing: 0.0) {
          VStack {
            Text(viewStore.title)
              .font(.title)

            if viewStore.isPlayAgainButtonVisible {
              Button("Play again?") {
                viewStore.send(.playAgainButtonTapped)
              }
              .padding(.top, 12)
              .font(.title)
            }
          }
          .padding(.bottom, 48)

          VStack {
            self.rowView(row: 0, proxy: proxy, viewStore: viewStore)
            self.rowView(row: 1, proxy: proxy, viewStore: viewStore)
            self.rowView(row: 2, proxy: proxy, viewStore: viewStore)
          }
          .disabled(viewStore.isGameDisabled)
        }
        .navigationTitle("Tic-tac-toe")
        .navigationBarItems(leading: Button("Quit") { viewStore.send(.quitButtonTapped) })
        .navigationBarBackButtonHidden(true)
      }
    }
  }

  func rowView(
    row: Int,
    proxy: GeometryProxy,
    viewStore: ViewStore<ViewState, Game.Action>
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
    viewStore: ViewStore<ViewState, Game.Action>
  ) -> some View {
    Button {
      viewStore.send(.cellTapped(row: row, column: column))
    } label: {
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

struct Game_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      GameView(
        store: Store(initialState: Game.State(oPlayerName: "Blob Jr.", xPlayerName: "Blob Sr.")) {
          Game()
        }
      )
    }
  }
}
