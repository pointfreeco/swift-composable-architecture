import ComposableArchitecture
import NewGameCore
import XCTest

@testable import NewGameSwiftUI

class NewGameSwiftUITests: XCTestCase {
  func testNewGame() {
    let store = Store(
      initialState: NewGameState(),
      reducer: newGameReducer,
      environment: NewGameEnvironment()
    )
    let viewStore = ViewStore(
      store.scope(state: NewGameView.ViewState.init, action: NewGameAction.init)
    )

    viewStore.send(.xPlayerNameChanged("Blob Sr."))
    XCTAssertEqual(
      .init(
        isGameActive: false,
        isLetsPlayButtonDisabled: true,
        oPlayerName: "",
        xPlayerName: "Blob Sr."
      ),
      viewStore.state
    )

    viewStore.send(.oPlayerNameChanged("Blob Jr."))
    XCTAssertEqual("Blob Jr.", viewStore.oPlayerName)
    XCTAssertEqual(false, viewStore.isLetsPlayButtonDisabled)

    viewStore.send(.letsPlayButtonTapped)
    XCTAssertEqual(true, viewStore.isGameActive)

    viewStore.send(.gameDismissed)
    XCTAssertEqual(false, viewStore.isGameActive)
  }
}
