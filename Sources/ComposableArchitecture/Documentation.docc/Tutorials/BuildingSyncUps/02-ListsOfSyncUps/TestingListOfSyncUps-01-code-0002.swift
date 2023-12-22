import ComposableArchitecture
import SyncUps
import XCTest

class SyncUpsListTests: XCTestCase {
  func testDeletion() async {
    let store = TestStore(
      initialState: SyncupsList.State(
        syncUps: [
          SyncUp(
            id: SyncUp.ID(),
            attendees: [],
            duration: .seconds(60),
            meetings: [],
            theme: .bubblegum,
            title: "Point-Free Morning Sync"
          )
        ]
      )
    ) {
      SyncUpsList()
    }
  }
}
