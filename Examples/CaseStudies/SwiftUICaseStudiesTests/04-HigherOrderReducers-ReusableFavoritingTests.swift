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

    await store.send(.episode(id: episodes[0].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[0].id]?.isFavorite = true
    }
    await clock.advance(by: .seconds(1))
    await store.receive(.episode(id: episodes[0].id, action: .favorite(.response(.success(true)))))

    await store.send(.episode(id: episodes[1].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[1].id]?.isFavorite = true
    }
    await store.send(.episode(id: episodes[1].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[1].id]?.isFavorite = false
    }
    await clock.advance(by: .seconds(1))
    await store.receive(.episode(id: episodes[1].id, action: .favorite(.response(.success(false)))))
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

    await store.send(.episode(id: episodes[0].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[0].id]?.isFavorite = true
    }

    await store.receive(
      .episode(
        id: episodes[0].id, action: .favorite(.response(.failure(FavoriteError()))))
    ) {
      $0.episodes[id: episodes[0].id]?.alert = AlertState {
        TextState("Favoriting failed.")
      }
    }

    await store.send(.episode(id: episodes[0].id, action: .favorite(.alertDismissed))) {
      $0.episodes[id: episodes[0].id]?.alert = nil
      $0.episodes[id: episodes[0].id]?.isFavorite = false
    }
  }
}
