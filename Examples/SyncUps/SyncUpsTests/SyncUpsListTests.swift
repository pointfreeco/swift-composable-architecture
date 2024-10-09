import ComposableArchitecture
import Foundation
import Testing

@testable import SyncUps

@MainActor
struct SyncUpsListTests {
  init() { uncheckedUseMainSerialExecutor = true }

  @Test
  func add() async throws {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    var syncUp = SyncUp(
      id: SyncUp.ID(UUID(0)),
      attendees: [
        Attendee(id: Attendee.ID(UUID(1)))
      ]
    )
    await store.send(.addSyncUpButtonTapped) {
      $0.destination = .add(SyncUpForm.State(syncUp: syncUp))
    }

    syncUp.title = "Engineering"
    await store.send(\.destination.add.binding.syncUp, syncUp) {
      $0.destination?.modify(\.add) { $0.syncUp.title = "Engineering" }
    }

    await store.send(.confirmAddSyncUpButtonTapped) {
      $0.destination = nil
      $0.syncUps = [syncUp]
    }
  }

  @Test
  func addAndConfirmValidatesAttendees() async throws {
    @Dependency(\.uuid) var uuid

    let store = TestStore(
      initialState: SyncUpsList.State(
        destination: .add(
          SyncUpForm.State(
            syncUp: SyncUp(
              id: SyncUp.ID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
              attendees: [
                Attendee(id: Attendee.ID(uuid()), name: ""),
                Attendee(id: Attendee.ID(uuid()), name: "    "),
              ],
              title: "Design"
            )
          )
        )
      )
    ) {
      SyncUpsList()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.confirmAddSyncUpButtonTapped) {
      $0.destination = nil
      $0.syncUps = [
        SyncUp(
          id: SyncUp.ID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
          attendees: [
            Attendee(id: Attendee.ID(UUID(0)))
          ],
          title: "Design"
        )
      ]
    }
  }
}
