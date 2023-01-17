import ComposableArchitecture
import XCTest

@testable import Standups

@MainActor
final class StandupDetailTests: XCTestCase {
  func testSpeechRestricted() async {
    let store = TestStore(
      initialState: StandupDetail.State(standup: .mock),
      reducer: StandupDetail()
    ) {
      $0.speechClient.authorizationStatus = { .restricted }
    }

    await store.send(.startMeetingButtonTapped) {
      $0.destination = .alert(.speechRecognitionRestricted)
    }
  }

  func testSpeechDenied() async throws {
    let store = TestStore(
      initialState: StandupDetail.State(standup: .mock),
      reducer: StandupDetail()
    ) {
      $0.speechClient.authorizationStatus = { .denied
      }
    }

    await store.send(.startMeetingButtonTapped) {
      $0.destination = .alert(.speechRecognitionDenied)
    }
  }

  func testOpenSettings() async {
    let settingsOpened = LockIsolated(false)

    let store = TestStore(
      initialState: StandupDetail.State(
        destination: .presented(
          id: UUID(),
          .alert(.speechRecognitionDenied)
        ),
        standup: .mock
      ),
      reducer: StandupDetail()
    ) {
      $0.openSettings = { settingsOpened.setValue(true) }
      $0.speechClient.authorizationStatus = { .denied }
    }

    await store.send(.destination(.presented(.alert(.openSettings)))) {
      $0.destination = nil
      XCTAssertEqual(settingsOpened.value, true)
    }
  }

  func testContinueWithoutRecording() async throws {
    let store = TestStore(
      initialState: StandupDetail.State(
        destination: .presented(
          id: UUID(), // TODO: hide the id?
          .alert(.speechRecognitionDenied)
        ),
        standup: .mock
      ),
      reducer: StandupDetail()
    ) {
      $0.speechClient.authorizationStatus = { .denied }
    }

    await store.send(.destination(.presented(.alert(.continueWithoutRecording)))) {
      $0.destination = nil
    }

    await store.receive(.delegate(.startMeeting))
  }

  func testSpeechAuthorized() async throws {
    let store = TestStore(
      initialState: StandupDetail.State(standup: .mock),
      reducer: StandupDetail()
    ) {
      $0.speechClient.authorizationStatus = { .authorized }
    }

    await store.send(.startMeetingButtonTapped)

    await store.receive(.delegate(.startMeeting))
  }

  func testEdit() async {
    let store = TestStore(
      initialState: StandupDetail.State(standup: .mock),
      reducer: StandupDetail()
    ) {
      $0.uuid = .incrementing
    }

    await store.send(.editButtonTapped) {
      $0.destination = .edit(EditStandup.State(standup: .mock))
    }

    await store.send(.destination(.presented(.edit(.set(\.$standup.title, "Blob's Meeting"))))) {
      try (/StandupDetail.Destinations.State.edit).modify(&$0.destination) {
        $0.standup.title = "Blob's Meeting"
      }
    }

    await store.send(.doneEditingButtonTapped) {
      $0.destination = nil
      $0.standup.title = "Blob's Meeting"
    }
  }
}
