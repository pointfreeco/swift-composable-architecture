import ComposableArchitecture
import XCTest

@testable import SyncUps

final class AppFeatureTests: XCTestCase {
  @MainActor
  func testDetailEdit() async throws {
    var syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    let sharedSyncUp = try XCTUnwrap($syncUps[id: syncUp.id])

    await store.send(\.path.push, (id: 0, .detail(SyncUpDetail.State(syncUp: sharedSyncUp)))) {
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: sharedSyncUp))
    }

    await store.send(\.path[id:0].detail.editButtonTapped) {
      $0.path[id: 0]?.detail?.destination = .edit(
        SyncUpForm.State(syncUp: syncUp)
      )
    }

    syncUp.title = "Blob"
    await store.send(\.path[id:0].detail.destination.edit.binding.syncUp, syncUp) {
      $0.path[id: 0]?.detail?.destination?.edit?.syncUp.title = "Blob"
    }

    await store.send(\.path[id:0].detail.doneEditingButtonTapped) {
      $0.path[id: 0]?.detail?.destination = nil
      $0.path[id: 0]?.detail?.syncUp.title = "Blob"
    }
    .finish()
  }

  @MainActor
  func testDelete() async throws {
    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    let sharedSyncUp = try XCTUnwrap($syncUps[id: syncUp.id])

    await store.send(\.path.push, (id: 0, .detail(SyncUpDetail.State(syncUp: sharedSyncUp)))) {
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: sharedSyncUp))
    }

    await store.send(\.path[id:0].detail.deleteButtonTapped) {
      $0.path[id: 0]?.detail?.destination = .alert(.deleteSyncUp)
    }

    await store.send(\.path[id:0].detail.destination.alert.confirmDeletion) {
      $0.path[id: 0, case: \.detail]?.destination = nil
      $0.syncUpsList.syncUps = []
    }

    await store.receive(\.path.popFrom) {
      $0.path = StackState()
    }
  }

  @MainActor
  func testRecording() async {
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

    let sharedSyncUp = Shared(syncUp)
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
    store.exhaustivity = .off

    await store.send(\.path[id:1].record.onTask)
    await store.receive(\.path.popFrom) {
      XCTAssertEqual($0.path.count, 1)
    }
    store.assert {
      $0.path[id: 0]?.detail?.syncUp.meetings = [
        Meeting(
          id: Meeting.ID(UUID(0)),
          date: Date(timeIntervalSince1970: 1_234_567_890),
          transcript: "I completed the project"
        )
      ]
    }
  }
}
