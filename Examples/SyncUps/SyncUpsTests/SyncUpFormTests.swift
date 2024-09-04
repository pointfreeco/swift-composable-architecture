import ComposableArchitecture
import XCTest

@testable import SyncUps

final class SyncUpFormTests: XCTestCase {
  func testAddAttendee() async {
    let store = await TestStore(
      initialState: SyncUpForm.State(
        syncUp: SyncUp(
          id: SyncUp.ID(),
          attendees: [],
          title: "Engineering"
        )
      )
    ) {
      SyncUpForm()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.assert {
      $0.syncUp.attendees = [Attendee(id: Attendee.ID(UUID(0)))]
    }

    await store.send(.addAttendeeButtonTapped) {
      $0.focus = .attendee(Attendee.ID(UUID(1)))
      $0.syncUp.attendees = [
        Attendee(id: Attendee.ID(UUID(0))),
        Attendee(id: Attendee.ID(UUID(1))),
      ]
    }
  }

  func testFocus_RemoveAttendee() async {
    let store = await TestStore(
      initialState: SyncUpForm.State(
        syncUp: SyncUp(
          id: SyncUp.ID(),
          attendees: [
            Attendee(id: Attendee.ID()),
            Attendee(id: Attendee.ID()),
            Attendee(id: Attendee.ID()),
            Attendee(id: Attendee.ID()),
          ],
          title: "Engineering"
        )
      )
    ) {
      SyncUpForm()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.deleteAttendees(atOffsets: [0])) {
      $0.focus = .attendee($0.syncUp.attendees[1].id)
      $0.syncUp.attendees = [
        $0.syncUp.attendees[1],
        $0.syncUp.attendees[2],
        $0.syncUp.attendees[3],
      ]
    }

    await store.send(.deleteAttendees(atOffsets: [1])) {
      $0.focus = .attendee($0.syncUp.attendees[2].id)
      $0.syncUp.attendees = [
        $0.syncUp.attendees[0],
        $0.syncUp.attendees[2],
      ]
    }

    await store.send(.deleteAttendees(atOffsets: [1])) {
      $0.focus = .attendee($0.syncUp.attendees[0].id)
      $0.syncUp.attendees = [
        $0.syncUp.attendees[0]
      ]
    }

    await store.send(.deleteAttendees(atOffsets: [0])) {
      $0.focus = .attendee(Attendee.ID(UUID(0)))
      $0.syncUp.attendees = [
        Attendee(id: Attendee.ID(UUID(0)))
      ]
    }
  }
}
