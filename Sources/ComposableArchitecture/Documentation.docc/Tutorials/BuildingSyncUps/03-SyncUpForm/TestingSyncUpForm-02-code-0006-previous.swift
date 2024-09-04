
import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpFormTests: XCTestCase {
  func testAddAttendee() async {
    let store = await TestStore(
      initialState: SyncUpForm.State(
        syncUp: SyncUp(id: SyncUp.ID())
      )
    ) {
      SyncUpForm()
    }

    await store.send(.addAttendeeButtonTapped) {
      let attendee = Attendee(id: Attendee.ID())
      $0.focus = .attendee(attendee.id)
      $0.syncUp.attendees.append(attendee)
    }
    // ❌ A state change does not match expectation: …
    //
    //       SyncUpForm.State(
    //         _focus: .attendee(
    //     −     Tagged(rawValue: UUID(B7833D85-CFA3-49A8-9B4C-54A4084372F7))
    //     +     Tagged(rawValue: UUID(AEF24FB1-BC0E-438A-85B8-1E045A9D8A88))
    //         ),
    //         _syncUp: SyncUp(
    //           id: Tagged(rawValue: UUID(D8CCE06C-F6BB-4D3D-A61A-59DF5D603B07)),
    //           attendees: [
    //             [0]: Attendee(
    //     −         id: Tagged(rawValue: UUID(B7833D85-CFA3-49A8-9B4C-54A4084372F7))
    //     +         id: Tagged(rawValue: UUID(AEF24FB1-BC0E-438A-85B8-1E045A9D8A88))
    //               name: ""
    //             )
    //           ],
    //           duration: 5 minutes,
    //           meetings: [],
    //           theme: .bubblegum,
    //           title: "Engineering"
    //         )
    //       )
    //
    // (Expected: −, Actual: +)
  }

  func testRemoveFocusedAttendee() async {
    // ...
  }

  func testRemoveAttendee() async {
    // ...
  }
}
