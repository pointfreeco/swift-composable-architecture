import ComposableArchitecture
import Foundation
import Testing

@testable import SyncUps

@MainActor
struct AppFeatureTests {
  init() { uncheckedUseMainSerialExecutor = true }

  @Test
  func detailEdit() async throws {
    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    let sharedSyncUp = try #require(Shared($syncUps[id: syncUp.id]))

    await store.send(\.path.push, (id: 0, .detail(SyncUpDetail.State(syncUp: sharedSyncUp)))) {
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: sharedSyncUp))
    }

    await store.send(\.path[id: 0].detail.editButtonTapped) {
      $0.path[id: 0]?.modify(\.detail) { $0.destination = .edit(SyncUpForm.State(syncUp: syncUp)) }
    }

    var newSyncUp = syncUp
    newSyncUp.title = "Blob"
    await store.send(\.path[id: 0].detail.destination.edit.binding.syncUp, newSyncUp) {
      $0.path[id: 0]?.modify(\.detail) {
        $0.destination?.modify(\.edit) { $0.syncUp.title = "Blob" }
      }
    }

    await store.send(\.path[id: 0].detail.doneEditingButtonTapped) {
      $0.path[id: 0]?.modify(\.detail) {
        $0.destination = nil
        $0.$syncUp.withLock { $0.title = "Blob" }
      }
    }
    .finish()
  }

  @Test
  func delete() async throws {
    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    let sharedSyncUp = try #require(Shared($syncUps[id: syncUp.id]))

    await store.send(\.path.push, (id: 0, .detail(SyncUpDetail.State(syncUp: sharedSyncUp)))) {
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: sharedSyncUp))
    }

    await store.send(\.path[id: 0].detail.deleteButtonTapped) {
      $0.path[id: 0]?.modify(\.detail) { $0.destination = .alert(.deleteSyncUp) }
    }

    await store.send(\.path[id: 0].detail.destination.alert.confirmDeletion) {
      $0.path[id: 0]?.modify(\.detail) { $0.destination = nil }
      $0.syncUpsList.$syncUps.withLock { $0 = [] }
    }

    await store.receive(\.path.popFrom) {
      $0.path = StackState()
    }
  }

  @Test
  func recording() async {
    let speechResult = SpeechRecognitionResult(
      bestTranscription: Transcription(formattedString: "I completed the project"),
      isFinal: true
    )
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      attendees: [
        Attendee(id: Attendee.ID()),
        Attendee(id: Attendee.ID()),
        Attendee(id: Attendee.ID()),
      ],
      duration: .seconds(6)
    )

    let sharedSyncUp = Shared(value: syncUp)
    let store = TestStore(
      initialState: AppFeature.State(
        path: StackState([
          .detail(SyncUpDetail.State(syncUp: sharedSyncUp)),
          .record(RecordMeeting.State(syncUp: sharedSyncUp)),
        ])
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      $0.continuousClock = ImmediateClock()
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        AsyncThrowingStream { continuation in
          continuation.yield(speechResult)
          continuation.finish()
        }
      }
      $0.uuid = .incrementing
    }

    await store.withExhaustivity(.off) {
      await store.send(\.path[id: 1].record.onTask)
      await store.receive(\.path.popFrom) {
        #expect($0.path.count == 1)
      }
    }
    await store.finish()
    store.assert {
      $0.path[id: 0]?.modify(\.detail) {
        $0.$syncUp.withLock {
          $0.meetings = [
            Meeting(
              id: Meeting.ID(UUID(0)),
              date: Date(timeIntervalSince1970: 1_234_567_890),
              transcript: "I completed the project"
            )
          ]
        }
      }
    }
  }
}
