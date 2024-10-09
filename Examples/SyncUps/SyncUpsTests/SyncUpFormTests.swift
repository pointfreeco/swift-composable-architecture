import ComposableArchitecture
import Foundation
import Testing

@testable import SyncUps

@MainActor
struct SyncUpFormTests {
  init() { uncheckedUseMainSerialExecutor = true }

  @Test
  func addAttendee() async {
    let store = TestStore(
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

    store.assert {
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

  @Test
  func focusAfterRemovingAttendee() async {
    let store = TestStore(
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
