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
  }
}
