import ComposableArchitecture
import XCTest

@testable import SyncUps

@MainActor
final class SyncUpDetailTests: XCTestCase {
  func testSpeechRestricted() async {
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: .mock)) {
      SyncUpDetail()
    } withDependencies: {
      $0.speechClient.authorizationStatus = { .restricted }
    }

    await store.send(.startMeetingButtonTapped) {
      $0.destination = .alert(.speechRecognitionRestricted)
    }
  }

  func testSpeechDenied() async throws {
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: .mock)) {
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

  func testOpenSettings() async {
    let settingsOpened = LockIsolated(false)

    let store = TestStore(
      initialState: SyncUpDetail.State(
        destination: .alert(.speechRecognitionDenied),
        syncUp: .mock
      )
    ) {
      SyncUpDetail()
    } withDependencies: {
      $0.openSettings = { settingsOpened.setValue(true) }
      $0.speechClient.authorizationStatus = { .denied }
    }

    await store.send(.destination(.presented(.alert(.openSettings)))) {
      $0.destination = nil
    }
    XCTAssertEqual(settingsOpened.value, true)
  }

  func testContinueWithoutRecording() async throws {
    let store = TestStore(
      initialState: SyncUpDetail.State(
        destination: .alert(.speechRecognitionDenied),
        syncUp: .mock
      )
    ) {
      SyncUpDetail()
    } withDependencies: {
      $0.speechClient.authorizationStatus = { .denied }
    }

    await store.send(.destination(.presented(.alert(.continueWithoutRecording)))) {
      $0.destination = nil
    }

    await store.receive(\.delegate.startMeeting)
  }

  func testSpeechAuthorized() async throws {
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: .mock)) {
      SyncUpDetail()
    } withDependencies: {
      $0.speechClient.authorizationStatus = { .authorized }
    }

    await store.send(.startMeetingButtonTapped)

    await store.receive(\.delegate.startMeeting)
  }

  func testEdit() async {
    var syncUp = SyncUp.mock
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: syncUp)) {
      SyncUpDetail()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.editButtonTapped) {
      $0.destination = .edit(SyncUpForm.State(syncUp: syncUp))
    }

    syncUp.title = "Blob's Meeting"
    await store.send(.destination(.presented(.edit(.set(\.syncUp, syncUp))))) {
      $0.$destination[case: \.edit]?.syncUp.title = "Blob's Meeting"
    }

    await store.send(.doneEditingButtonTapped) {
      $0.destination = nil
      $0.syncUp.title = "Blob's Meeting"
    }

    await store.receive(\.delegate.syncUpUpdated)
  }

  func testDelete() async {
    let didDismiss = LockIsolated(false)
    defer { XCTAssertEqual(didDismiss.value, true) }

    let syncUp = SyncUp.mock
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: syncUp)) {
      SyncUpDetail()
    } withDependencies: {
      $0.dismiss = DismissEffect {
        didDismiss.setValue(true)
      }
    }

    await store.send(.deleteButtonTapped) {
      $0.destination = .alert(.deleteSyncUp)
    }
    await store.send(.destination(.presented(.alert(.confirmDeletion)))) {
      $0.destination = nil
    }
    await store.receive(\.delegate.deleteSyncUp)
  }
}
