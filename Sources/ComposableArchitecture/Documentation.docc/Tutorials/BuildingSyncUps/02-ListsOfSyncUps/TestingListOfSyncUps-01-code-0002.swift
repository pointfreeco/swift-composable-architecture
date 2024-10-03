import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct SyncUpsListTests {
  @Test
  func deletion() async {
    let store = TestStore(
      initialState: SyncUpsList.State(
        syncUps: [
          SyncUp(
            id: SyncUp.ID(),
            title: "Point-Free Morning Sync"
          )
        ]
      )
    ) {
      SyncUpsList()
    }
  }
}
