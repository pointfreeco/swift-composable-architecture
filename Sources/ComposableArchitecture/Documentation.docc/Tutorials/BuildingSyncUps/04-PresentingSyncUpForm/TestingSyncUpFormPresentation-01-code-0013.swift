import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct SyncUpsListTests {
  @Test
  func addSyncUp() async {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.addSyncUpButtonTapped) {
      $0.addSyncUp = SyncUpForm.State(
        syncUp: SyncUp(id: SyncUp.ID(0))
      )
    }

    let editedSyncUp = SyncUp(
      id: SyncUp.ID(0),
      attendees: [
        Attendee(id: Attendee.ID(), name: "Blob"),
        Attendee(id: Attendee.ID(), name: "Blob Jr."),
      ],
      title: "Point-Free morning sync"
    )
    await store.send(\.addSyncUp.binding.syncUp, editedSyncUp) {
      $0.addSyncUp?.syncUp = editedSyncUp
    }

    await store.send(.confirmAddButtonTapped)
    // ❌ State was not expected to change, but a change occurred: …
    //
    //       SyncUpsList.State(
    //     −   _addSyncUp: SyncUpForm.State(
    //     −     _focus: .title,
    //     −     _syncUp: SyncUp(
    //     −       id: Tagged(rawValue: UUID(00000000-0000-0000-0000-000000000000)),
    //     −       attendees: [
    //     −         [0]: Attendee(
    //     −           id: Tagged(rawValue: UUID(0C804547-B60D-48D5-A5CC-BBC16D1B2287)),
    //     −           name: "Blob"
    //     −         ),
    //     −         [1]: Attendee(
    //     −           id: Tagged(rawValue: UUID(70B92063-FE08-458F-9703-E2E627A88EDA)),
    //     −           name: "Blob Jr."
    //     −         )
    //     −       ],
    //     −       duration: 5 minutes,
    //     −       meetings: [],
    //     −       theme: .bubblegum,
    //     −       title: "Point-Free morning sync"
    //     −     )
    //     −   ),
    //     +   _addSyncUp: nil,
    //         _syncUps: [
    //     +     [0]: SyncUp(
    //     +       id: Tagged(rawValue: UUID(00000000-0000-0000-0000-000000000000)),
    //     +       attendees: [
    //     +         [0]: Attendee(
    //     +           id: Tagged(rawValue: UUID(0C804547-B60D-48D5-A5CC-BBC16D1B2287)),
    //     +           name: "Blob"
    //     +         ),
    //     +         [1]: Attendee(
    //     +           id: Tagged(rawValue: UUID(70B92063-FE08-458F-9703-E2E627A88EDA)),
    //     +           name: "Blob Jr."
    //     +         )
    //     +       ],
    //     +       duration: 5 minutes,
    //     +       meetings: [],
    //     +       theme: .bubblegum,
    //     +       title: "Point-Free morning sync"
    //     +     )
    //         ]
    //       )
    //
    // (Expected: −, Actual: +)
  }

  @Test
  func deletion() async {
    // ...
  }
}
