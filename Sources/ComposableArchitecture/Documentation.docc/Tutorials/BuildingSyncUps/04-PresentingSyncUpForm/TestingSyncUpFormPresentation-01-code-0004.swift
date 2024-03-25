import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpsListTests: XCTestCase {
  @MainActor
  func testAddSyncUp() async {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    }

    await store.send(.addSyncUpButtonTapped) {
      $0.addSyncUp = SyncUpForm.State(syncUp: SyncUp(id: SyncUp.ID()))
    }
    // ❌ A state change does not match expectation: …
    //
    //       SyncUpsList.State(
    //         _addSyncUp: SyncUpForm.State(
    //           _focus: .title,
    //           _syncUp: SyncUp(
    //     −       id: Tagged(rawValue: UUID(46714C1B-449D-430C-9AE9-300BEF39D259))
    //     +       id: Tagged(rawValue: UUID(29CEC58B-1FC1-443C-8178-D35C9CA062C1))
    //             attendees: [],
    //             duration: 5 minutes,
    //             meetings: [],
    //             theme: .bubblegum,
    //             title: ""
    //           )
    //         ),
    //         _syncUps: []
    //       )
    //
    // (Expected: −, Actual: +)
  }

  @MainActor
  func testDeletion() async {
    // ...
  }
}
