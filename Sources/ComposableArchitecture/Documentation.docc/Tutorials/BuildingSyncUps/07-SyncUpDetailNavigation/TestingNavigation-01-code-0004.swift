import ComposableArchitecture
import XCTest

@testable import SyncUps

final class AppFeatureTests: XCTestCase {@MainActor
  func testDelete() async throws {
    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    await store.send(\.path.push, (id: 0, .detail(SyncUpDetail.State(syncUp: ???)))) {

    }
  }
}
