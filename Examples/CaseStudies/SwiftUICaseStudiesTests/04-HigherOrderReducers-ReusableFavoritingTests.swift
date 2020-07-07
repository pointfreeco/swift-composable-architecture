import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class ReusableComponentsFavoritingTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testFavoriteButton() {
    let store = TestStore(
      initialState: EpisodesState(
        episodes: [
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
      ),
      reducer: episodesReducer,
      environment: EpisodesEnvironment(
        favorite: { _, isFavorite in Effect.future { $0(.success(isFavorite)) } },
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    let error = NSError(domain: "co.pointfree", code: -1, userInfo: nil)
    store.assert(
      .send(.episode(index: 0, action: .favorite(.buttonTapped))) {
        $0.episodes[0].isFavorite = true
      },

      .do { self.scheduler.advance() },
      .receive(.episode(index: 0, action: .favorite(.response(.success(true))))),

      .send(.episode(index: 1, action: .favorite(.buttonTapped))) {
        $0.episodes[1].isFavorite = true
      },
      .send(.episode(index: 1, action: .favorite(.buttonTapped))) {
        $0.episodes[1].isFavorite = false
      },

      .do { self.scheduler.advance() },
      .receive(.episode(index: 1, action: .favorite(.response(.success(false))))),

      .environment {
        $0.favorite = { _, _ in Effect.future { $0(.failure(error)) } }
      },
      .send(.episode(index: 2, action: .favorite(.buttonTapped))) {
        $0.episodes[2].isFavorite = true
      },

      .do { self.scheduler.advance() },
      .receive(
        .episode(index: 2, action: .favorite(.response(.failure(FavoriteError(error: error)))))
      ) {
        $0.episodes[2].alert = .init(
          title: "The operation couldn’t be completed. (co.pointfree error -1.)"
        )
      },

      .send(.episode(index: 2, action: .favorite(.alertDismissed))) {
        $0.episodes[2].alert = nil
        $0.episodes[2].isFavorite = false
      }
    )
  }
}
