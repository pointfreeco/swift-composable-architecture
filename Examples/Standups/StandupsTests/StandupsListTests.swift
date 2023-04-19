import ComposableArchitecture
import XCTest

@testable import Standups

@MainActor
final class StandupsListTests: XCTestCase {
  func testAdd() async throws {
    let store = withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock()
      $0.uuid = .incrementing
    } operation: {
      TestStore(
        initialState: StandupsList.State(),
        reducer: StandupsList()
      )
    }

    await store.send(.addStandupButtonTapped) {
      $0.destination = .add(
        StandupForm.State(
          standup: Standup(
            id: Standup.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            attendees: [
              Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
            ]
          )
        )
      )
    }

    await store.send(
      .destination(.presented(.add(.binding(.set(\.$standup.title, "Engineering")))))
    ) {
      XCTModify(&$0.destination, case: /StandupsList.Destination.State.add) {
        $0.standup.title = "Engineering"
      }
    }

    await store.send(.confirmAddStandupButtonTapped) {
      $0.destination = nil
      $0.standups = [
        Standup(
          id: Standup.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          attendees: [
            Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
          ],
          title: "Engineering"
        )
      ]
    }
  }

  func testAdd_ValidatedAttendees() async throws {
    @Dependency(\.uuid) var uuid

    let store = TestStore(
      initialState: StandupsList.State(
        destination: .add(
          StandupForm.State(
            standup: Standup(
              id: Standup.ID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
              attendees: [
                Attendee(id: Attendee.ID(uuid()), name: ""),
                Attendee(id: Attendee.ID(uuid()), name: "    "),
              ],
              title: "Design"
            )
          )
        )
      ),
      reducer: StandupsList()
    ) {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock()
      $0.uuid = .incrementing
    }

    await store.send(.confirmAddStandupButtonTapped) {
      $0.destination = nil
      $0.standups = [
        Standup(
          id: Standup.ID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
          attendees: [
            Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!)
          ],
          title: "Design"
        )
      ]
    }
  }

  func testLoadingDataDecodingFailed() async throws {
    let store = TestStore(
      initialState: StandupsList.State(),
      reducer: StandupsList()
    ) {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock(
        initialData: Data("!@#$ BAD DATA %^&*()".utf8)
      )
    }

    XCTAssertEqual(store.state.destination, .alert(.dataFailedToLoad))

    await store.send(.destination(.presented(.alert(.confirmLoadMockData)))) {
      $0.destination = nil
      $0.standups = [
        .mock,
        .designMock,
        .engineeringMock,
      ]
    }
  }

  func testLoadingDataFileNotFound() async throws {
    let store = TestStore(
      initialState: StandupsList.State(),
      reducer: StandupsList()
    ) {
      $0.continuousClock = ImmediateClock()
      $0.dataManager.load = { _ in
        struct FileNotFound: Error {}
        throw FileNotFound()
      }
    }

    XCTAssertEqual(store.state.destination, nil)
  }
}
