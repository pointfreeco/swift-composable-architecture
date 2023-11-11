import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class ReusableComponentsFavoritingTests: XCTestCase {
  func testHappyPath() async {
    let clock = TestClock()

    let episodes: IdentifiedArrayOf<Episode.State> = [
      Episode.State(
        id: UUID(0),
        isFavorite: false,
        title: "Functions"
      ),
      Episode.State(
        id: UUID(1),
        isFavorite: false,
        title: "Functions"
      ),
      Episode.State(
        id: UUID(2),
        isFavorite: false,
        title: "Functions"
      ),
    ]
    let store = TestStore(initialState: Episodes.State(episodes: episodes)) {
      Episodes(
        favorite: { _, isFavorite in
          try await clock.sleep(for: .seconds(1))
          return isFavorite
        }
      )
    }

    await store.send(.episodes(.element(id: episodes[0].id, action: .favorite(.buttonTapped)))) {
      $0.episodes[id: episodes[0].id]?.isFavorite = true
    }
    await clock.advance(by: .seconds(1))
    await store.receive(\.episodes[id:episodes[0].id].favorite.response.success)

    await store.send(.episodes(.element(id: episodes[1].id, action: .favorite(.buttonTapped)))) {
      $0.episodes[id: episodes[1].id]?.isFavorite = true
    }
    await store.send(.episodes(.element(id: episodes[1].id, action: .favorite(.buttonTapped)))) {
      $0.episodes[id: episodes[1].id]?.isFavorite = false
    }
    await clock.advance(by: .seconds(1))
    await store.receive(\.episodes[id:episodes[1].id].favorite.response.success)
  }

  func testUnhappyPath() async {
    let episodes: IdentifiedArrayOf<Episode.State> = [
      Episode.State(
        id: UUID(0),
        isFavorite: false,
        title: "Functions"
      )
    ]
    let store = TestStore(initialState: Episodes.State(episodes: episodes)) {
      Episodes(favorite: { _, _ in throw FavoriteError() })
    }

    await store.send(.episodes(.element(id: episodes[0].id, action: .favorite(.buttonTapped)))) {
      $0.episodes[id: episodes[0].id]?.isFavorite = true
    }

    await store.receive(\.episodes[id:episodes[0].id].favorite.response.failure) {
      $0.episodes[id: episodes[0].id]?.alert = AlertState {
        TextState("Favoriting failed.")
      }
    }

    await store.send(.episodes(.element(id: episodes[0].id, action: .favorite(.alert(.dismiss))))) {
      $0.episodes[id: episodes[0].id]?.alert = nil
      $0.episodes[id: episodes[0].id]?.isFavorite = false
    }
  }
}
