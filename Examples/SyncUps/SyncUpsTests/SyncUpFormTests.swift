import ComposableArchitecture
import XCTest

@testable import SyncUps

@MainActor
final class SyncUpFormTests: XCTestCase {
  func testAddAttendee() async {
    let store = TestStore(
      initialState: SyncUpForm.State(
        syncUp: Ref(
          SyncUp(
            id: SyncUp.ID(),
            attendees: [],
            title: "Engineering"
          )
        )
      )
    ) {
      SyncUpForm()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    XCTAssertNoDifference(
      store.state.syncUp.attendees,
      [
        Attendee(id: Attendee.ID(UUID(0)))
      ]
    )

    await store.send(.addAttendeeButtonTapped) {
      $0.focus = .attendee(Attendee.ID(UUID(1)))
      $0.syncUp.attendees = [
        Attendee(id: Attendee.ID(UUID(0))),
        Attendee(id: Attendee.ID(UUID(1))),
      ]
    }
  }

  func testFocus_RemoveAttendee() async {
    let store = TestStore(
      initialState: SyncUpForm.State(
        syncUp: Ref(
          SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID(UUID(0))),
              Attendee(id: Attendee.ID(UUID(1))),
              Attendee(id: Attendee.ID(UUID(2))),
              Attendee(id: Attendee.ID(UUID(3))),
            ],
            title: "Engineering"
          )
        )
      )
    ) {
      SyncUpForm()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.deleteAttendees(atOffsets: [0])) {
      $0.focus = .attendee(Attendee.ID(UUID(1)))
      XCTAssertEqual($0.syncUp.attendees.map(\.id.rawValue), [UUID(1), UUID(2), UUID(3)])
    }

    await store.send(.deleteAttendees(atOffsets: [1])) {
      $0.focus = .attendee($0.syncUp.attendees[1].id)
      XCTAssertEqual($0.syncUp.attendees.count, 2)
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
