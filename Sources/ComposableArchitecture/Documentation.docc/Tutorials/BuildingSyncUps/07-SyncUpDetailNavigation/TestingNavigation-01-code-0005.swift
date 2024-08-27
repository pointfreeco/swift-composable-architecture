import ComposableArchitecture
import XCTest

@testable import SyncUps

final class AppFeatureTests: XCTestCase {
  func testDelete() async throws {
    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]

    let store = await TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    let sharedSyncUp = try XCTUnwrap($syncUps[id: syncUp.id])

    await store.send(\.path.push, (id: 0, .detail(SyncUpDetail.State(syncUp: sharedSyncUp)))) {
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: sharedSyncUp))
    }
  }
}
