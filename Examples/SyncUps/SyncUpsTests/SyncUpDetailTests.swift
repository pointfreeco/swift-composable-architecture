import ComposableArchitecture
import XCTest

@testable import SyncUps

final class SyncUpDetailTests: XCTestCase {
  @MainActor
  func testSpeechRestricted() async {
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(.mock))) {
      SyncUpDetail()
    } withDependencies: {
      $0.speechClient.authorizationStatus = { .restricted }
    }

    await store.send(.startMeetingButtonTapped) {
      $0.destination = .alert(.speechRecognitionRestricted)
    }
  }

  @MainActor
  func testSpeechDenied() async throws {
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(.mock))) {
      SyncUpDetail()
    } withDependencies: {
      $0.speechClient.authorizationStatus = {
        .denied
      }
    }

    await store.send(.startMeetingButtonTapped) {
      $0.destination = .alert(.speechRecognitionDenied)
    }
  }

  @MainActor
  func testOpenSettings() async {
    let settingsOpened = LockIsolated(false)

    let store = TestStore(
      initialState: SyncUpDetail.State(
        destination: .alert(.speechRecognitionDenied),
        syncUp: Shared(.mock)
      )
    ) {
      SyncUpDetail()
    } withDependencies: {
      $0.openSettings = { settingsOpened.setValue(true) }
      $0.speechClient.authorizationStatus = { .denied }
    }

    await store.send(\.destination.alert.openSettings) {
      $0.destination = nil
    }
    XCTAssertEqual(settingsOpened.value, true)
  }

  @MainActor
  func testContinueWithoutRecording() async throws {
    let store = TestStore(
      initialState: SyncUpDetail.State(
        destination: .alert(.speechRecognitionDenied),
        syncUp: Shared(.mock)
      )
    ) {
      SyncUpDetail()
    } withDependencies: {
      $0.speechClient.authorizationStatus = { .denied }
    }

    await store.send(\.destination.alert.continueWithoutRecording) {
      $0.destination = nil
    }

    await store.receive(\.delegate.startMeeting)
  }

  @MainActor
  func testSpeechAuthorized() async throws {
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(.mock))) {
      SyncUpDetail()
    } withDependencies: {
      $0.speechClient.authorizationStatus = { .authorized }
    }

    await store.send(.startMeetingButtonTapped)

    await store.receive(\.delegate.startMeeting)
  }

  @MainActor
  func testEdit() async {
    var syncUp = SyncUp.mock
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(syncUp))) {
      SyncUpDetail()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.editButtonTapped) {
      $0.destination = .edit(SyncUpForm.State(syncUp: syncUp))
    }

    syncUp.title = "Blob's Meeting"
    await store.send(\.destination.edit.binding.syncUp, syncUp) {
      $0.destination?.edit?.syncUp.title = "Blob's Meeting"
    }

    await store.send(.doneEditingButtonTapped) {
      $0.destination = nil
      $0.syncUp.title = "Blob's Meeting"
    }
  }

  @MainActor
  func testDelete() async throws {
    let didDismiss = LockIsolated(false)
    defer { XCTAssertEqual(didDismiss.value, true) }

    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]
    // TODO: Can this exhaustively be caught?
    defer { XCTAssertEqual([], syncUps) }

    let sharedSyncUp = try XCTUnwrap($syncUps[id: syncUp.id])
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: sharedSyncUp)) {
      SyncUpDetail()
    } withDependencies: {
      $0.dismiss = DismissEffect {
        didDismiss.setValue(true)
      }
    }

    await store.send(.deleteButtonTapped) {
      $0.destination = .alert(.deleteSyncUp)
    }
    await store.send(\.destination.alert.confirmDeletion) {
      $0.destination = nil
    }
  }
}
