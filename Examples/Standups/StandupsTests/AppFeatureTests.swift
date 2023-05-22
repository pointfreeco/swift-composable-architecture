import ComposableArchitecture
import XCTest

@testable import Standups

@MainActor
final class AppFeatureTests: XCTestCase {
  func testDelete() async throws {
    let standup = Standup.mock

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock(
        initialData: try! JSONEncoder().encode([standup])
      )
    }

    await store.send(.path(.push(id: 0, state: .detail(StandupDetail.State(standup: standup))))) {
      $0.path[id: 0] = .detail(StandupDetail.State(standup: standup))
    }

    await store.send(.path(.element(id: 0, action: .detail(.deleteButtonTapped)))) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.destination = .alert(.deleteStandup)
      }
    }

    await store.send(
      .path(.element(id: 0, action: .detail(.destination(.presented(.alert(.confirmDeletion))))))
    ) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.destination = nil
      }
    }

    await store.receive(.path(.element(id: 0, action: .detail(.delegate(.deleteStandup))))) {
      $0.standupsList.standups = []
    }
    await store.receive(.path(.popFrom(id: 0))) {
      $0.path = StackState()
    }
  }

  func testDetailEdit() async throws {
    let standup = Standup.mock
    let savedData = LockIsolated(Data?.none)

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: { dependencies in
      dependencies.continuousClock = ImmediateClock()
      dependencies.dataManager = .mock(
        initialData: try! JSONEncoder().encode([standup])
      )
      dependencies.dataManager.save = { [dependencies] data, url in
        savedData.setValue(data)
        try await dependencies.dataManager.save(data, url)
      }
    }

    await store.send(.path(.push(id: 0, state: .detail(StandupDetail.State(standup: standup))))) {
      $0.path[id: 0] = .detail(StandupDetail.State(standup: standup))
    }

    await store.send(.path(.element(id: 0, action: .detail(.editButtonTapped)))) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.destination = .edit(StandupForm.State(standup: standup))
      }
    }

    await store.send(
      .path(
        .element(
          id: 0,
          action: .detail(.destination(.presented(.edit(.binding(.set(\.$standup.title, "Blob"))))))
        )
      )
    ) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        XCTModify(&$0.destination, case: /StandupDetail.Destination.State.edit) {
          $0.standup.title = "Blob"
        }
      }
    }

    await store.send(.path(.element(id: 0, action: .detail(.doneEditingButtonTapped)))) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.destination = nil
        $0.standup.title = "Blob"
      }
    }

    await store.send(.path(.popFrom(id: 0))) {
      $0.path = StackState()
      $0.standupsList.standups[0].title = "Blob"
    }
    .finish()

    var savedStandup = standup
    savedStandup.title = "Blob"
    XCTAssertEqual(savedData.value, try! JSONEncoder().encode([savedStandup]))
  }

  func testRecording() async {
    let speechResult = SpeechRecognitionResult(
      bestTranscription: Transcription(formattedString: "I completed the project"),
      isFinal: true
    )
    let standup = Standup(
      id: Standup.ID(),
      attendees: [
        Attendee(id: Attendee.ID()),
        Attendee(id: Attendee.ID()),
        Attendee(id: Attendee.ID()),
      ],
      duration: .seconds(6)
    )

    let store = TestStore(
      initialState: AppFeature.State(
        path: StackState([
          .detail(StandupDetail.State(standup: standup)),
          .record(RecordMeeting.State(standup: standup)),
        ])
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.dataManager = .mock(initialData: try! JSONEncoder().encode([standup]))
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      $0.continuousClock = ImmediateClock()
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { _ in
        AsyncThrowingStream { continuation in
          continuation.yield(speechResult)
          continuation.finish()
        }
      }
      $0.uuid = .incrementing
    }
    store.exhaustivity = .off

    await store.send(.path(.element(id: 1, action: .record(.task))))
    await store.receive(
      .path(
        .element(id: 1, action: .record(.delegate(.save(transcript: "I completed the project"))))
      )
    ) {
      $0.path.pop(to: 0)
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.standup.meetings = [
          Meeting(
            id: Meeting.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            date: Date(timeIntervalSince1970: 1_234_567_890),
            transcript: "I completed the project"
          )
        ]
      }
    }
  }
}
