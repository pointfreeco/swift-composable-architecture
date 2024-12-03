import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct SyncUpDetailTests {
  init() { uncheckedUseMainSerialExecutor = true }

  @Test
  func speechRestricted() async {
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(value: .mock))) {
      SyncUpDetail()
    } withDependencies: {
      $0.speechClient.authorizationStatus = { .restricted }
    }

    await store.send(.startMeetingButtonTapped) {
      $0.destination = .alert(.speechRecognitionRestricted)
    }
  }

  @Test
  func speechDenied() async throws {
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(value: .mock))) {
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

  @Test
  func openSettings() async {
    let settingsOpened = LockIsolated(false)

    let store = TestStore(
      initialState: SyncUpDetail.State(
        destination: .alert(.speechRecognitionDenied),
        syncUp: Shared(value: .mock)
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
    #expect(settingsOpened.value)
  }

  @Test
  func continueWithoutRecording() async throws {
    let store = TestStore(
      initialState: SyncUpDetail.State(
        destination: .alert(.speechRecognitionDenied),
        syncUp: Shared(value: .mock)
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

  @Test
  func speechAuthorized() async throws {
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(value: .mock))) {
      SyncUpDetail()
    } withDependencies: {
      $0.speechClient.authorizationStatus = { .authorized }
    }

    await store.send(.startMeetingButtonTapped)

    await store.receive(\.delegate.startMeeting)
  }

  @Test
  func edit() async {
    var syncUp = SyncUp.mock
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(value: syncUp))) {
      SyncUpDetail()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.editButtonTapped) {
      $0.destination = .edit(SyncUpForm.State(syncUp: syncUp))
    }

    syncUp.title = "Blob's Meeting"
    await store.send(\.destination.edit.binding.syncUp, syncUp) {
      $0.destination?.modify(\.edit) { $0.syncUp.title = "Blob's Meeting" }
    }

    await store.send(.doneEditingButtonTapped) {
      $0.destination = nil
      $0.$syncUp.withLock { $0.title = "Blob's Meeting" }
    }
  }

  @Test
  func delete() async throws {
    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]
    // TODO: Can this exhaustively be caught?
    defer { #expect(syncUps == []) }

    let sharedSyncUp = try #require(Shared($syncUps[id: syncUp.id]))
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: sharedSyncUp)) {
      SyncUpDetail()
    }
    await store.send(.deleteButtonTapped) {
      $0.destination = .alert(.deleteSyncUp)
    }
    await store.send(\.destination.alert.confirmDeletion) {
      $0.destination = nil
    }
    #expect(store.isDismissed)
  }
}
