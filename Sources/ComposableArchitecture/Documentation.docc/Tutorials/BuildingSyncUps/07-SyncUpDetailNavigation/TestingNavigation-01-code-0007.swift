import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct AppFeatureTests {
  @Test
  func delete() async throws {
    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    let sharedSyncUp = try #require($syncUps[id: syncUp.id])

    await store.send(\.path.push, (id: 0, .detail(SyncUpDetail.State(syncUp: sharedSyncUp)))) {
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: sharedSyncUp))
    }

    await store.send(\.path[id:0].detail.deleteButtonTapped) {
      $0.path[id: 0]?.detail?.destination = .alert(.deleteSyncUp)
    }

    await store.send(\.path[id:0].detail.destination.alert.confirmButtonTapped) {
      $0.path[id: 0, case: \.detail]?.destination = nil
      $0.syncUpsList.syncUps = []
    }
  }
}
