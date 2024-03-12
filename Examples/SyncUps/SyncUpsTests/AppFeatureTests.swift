import ComposableArchitecture
import XCTest

@testable import SyncUps

final class AppFeatureTests: XCTestCase {
  @MainActor
  func testDelete() async throws {
    let syncUp = SyncUp.mock

    let store = TestStore(
      initialState: AppFeature.State(syncUpsList: SyncUpsList.State(syncUps: [syncUp]))
    ) {
      AppFeature()
    }

    await store.send(
      \.path.push, (id: 0, .detail(SyncUpDetail.State(syncUp: store.state.syncUpsList.$syncUps[0])))
    ) {
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: Shared(syncUp)))
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
  func testDetailEdit() async throws {
    var syncUp = SyncUp.mock

    let store = TestStore(
      initialState: AppFeature.State(syncUpsList: SyncUpsList.State(syncUps: [syncUp]))
    ) {
      AppFeature()
    }

    await store.send(
      \.path.push, (id: 0, .detail(SyncUpDetail.State(syncUp: store.state.syncUpsList.$syncUps[0])))
    ) {
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: Shared(syncUp)))
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
  }
}
