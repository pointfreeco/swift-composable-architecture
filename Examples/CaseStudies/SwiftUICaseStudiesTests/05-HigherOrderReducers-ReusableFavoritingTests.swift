import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class ReusableComponentsFavoritingTests: XCTestCase {
  @MainActor
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

    await store.send(\.episodes[id:UUID(0)].favorite.buttonTapped) {
      $0.episodes[id: UUID(0)]?.isFavorite = true
    }
    await clock.advance(by: .seconds(1))
    await store.receive(\.episodes[id:episodes[0].id].favorite.response.success)

    await store.send(\.episodes[id:episodes[1].id].favorite.buttonTapped) {
      $0.episodes[id: UUID(1)]?.isFavorite = true
    }
    await store.send(\.episodes[id:episodes[1].id].favorite.buttonTapped) {
      $0.episodes[id: UUID(1)]?.isFavorite = false
    }
    await clock.advance(by: .seconds(1))
    await store.receive(\.episodes[id:episodes[1].id].favorite.response.success)
  }

  @MainActor
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

    await store.send(\.episodes[id:UUID(0)].favorite.buttonTapped) {
      $0.episodes[id: UUID(0)]?.isFavorite = true
    }

    await store.receive(\.episodes[id:episodes[0].id].favorite.response.failure) {
      $0.episodes[id: UUID(0)]?.alert = AlertState {
        TextState("Favoriting failed.")
      }
    }

    await store.send(\.episodes[id:UUID(0)].favorite.alert.dismiss) {
      $0.episodes[id: UUID(0)]?.alert = nil
      $0.episodes[id: UUID(0)]?.isFavorite = false
    }
  }
}
