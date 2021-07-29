import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class ReusableComponentsFavoritingTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testFavoriteButton() {
    let episodes: IdentifiedArrayOf<EpisodeState> = [
      .init(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        isFavorite: false,
        title: "Functions"
      ),
      .init(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        isFavorite: false,
        title: "Functions"
      ),
      .init(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        isFavorite: false,
        title: "Functions"
      ),
    ]
    let store = TestStore(
      initialState: EpisodesState(episodes: episodes),
      reducer: episodesReducer,
      environment: EpisodesEnvironment(
        favorite: { _, isFavorite in Effect.future { $0(.success(isFavorite)) } },
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    let error = NSError(domain: "co.pointfree", code: -1, userInfo: nil)
    store.send(.episode(id: episodes[0].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[0].id]?.isFavorite = true
    }

    self.scheduler.advance()
    store.receive(.episode(id: episodes[0].id, action: .favorite(.response(.success(true)))))

    store.send(.episode(id: episodes[1].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[1].id]?.isFavorite = true
    }
    store.send(.episode(id: episodes[1].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[1].id]?.isFavorite = false
    }

    self.scheduler.advance()
    store.receive(.episode(id: episodes[1].id, action: .favorite(.response(.success(false)))))

    store.environment.favorite = { _, _ in .future { $0(.failure(error)) } }
    store.send(.episode(id: episodes[2].id, action: .favorite(.buttonTapped))) {
      $0.episodes[id: episodes[2].id]?.isFavorite = true
    }

    self.scheduler.advance()
    store.receive(
      .episode(
        id: episodes[2].id, action: .favorite(.response(.failure(FavoriteError(error: error)))))
    ) {
      $0.episodes[id: episodes[2].id]?.alert = .init(
        title: .init("The operation couldn’t be completed. (co.pointfree error -1.)")
      )
    }

    store.send(.episode(id: episodes[2].id, action: .favorite(.alertDismissed))) {
      $0.episodes[id: episodes[2].id]?.alert = nil
      $0.episodes[id: episodes[2].id]?.isFavorite = false
    }
  }
}
