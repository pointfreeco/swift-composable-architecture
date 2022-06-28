import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class ReusableComponentsFavoritingTests: XCTestCase {
  func testFavoriteButton() async {
    let episodes: IdentifiedArrayOf<EpisodeState> = [
      EpisodeState(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        isFavorite: false,
        title: "Functions"
      ),
      EpisodeState(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        isFavorite: false,
        title: "Functions"
      ),
      EpisodeState(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        isFavorite: false,
        title: "Functions"
      ),
    ]
    let store = TestStore(
      initialState: EpisodesState(episodes: episodes),
      reducer: episodesReducer,
      environment: EpisodesEnvironment(
        favorite: { _, isFavorite in isFavorite }
      )
    )

    store.send(.episode(id: episodes[0].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[0].id]?.isFavorite = true
    }

    await store.receive(.episode(id: episodes[0].id, action: .favorite(.response(.success(true)))))

    store.send(.episode(id: episodes[1].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[1].id]?.isFavorite = true
    }
    store.send(.episode(id: episodes[1].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[1].id]?.isFavorite = false
    }

    await store.receive(.episode(id: episodes[1].id, action: .favorite(.response(.success(false)))))

    struct FavoriteError: Equatable, LocalizedError {
      var errorDescription: String? {
        "Favoriting failed."
      }
    }
    store.environment.favorite = { _, _ in throw FavoriteError() }
    store.send(.episode(id: episodes[2].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[2].id]?.isFavorite = true
    }

    await store.receive(
      .episode(
        id: episodes[2].id, action: .favorite(.response(.failure(FavoriteError()))))
    ) {
      $0.episodes[id: episodes[2].id]?.alert = AlertState(
        title: TextState("Favoriting failed.")
      )
    }

    store.send(.episode(id: episodes[2].id, action: .favorite(.alertDismissed))) {
      $0.episodes[id: episodes[2].id]?.alert = nil
      $0.episodes[id: episodes[2].id]?.isFavorite = false
    }
  }
}
