import ComposableArchitecture
import XCTest

@testable import Standups

@MainActor
final class StandupsListTests: XCTestCase {
  func testAdd() async throws {
    let store = TestStore(initialState: StandupsList.State()) {
      StandupsList()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock()
      $0.uuid = .incrementing
    }

    var standup = Standup(
      id: Standup.ID(UUID(0)),
      attendees: [
        Attendee(id: Attendee.ID(UUID(1)))
      ]
    )
    await store.send(.addStandupButtonTapped) {
      $0.destination = .add(StandupForm.State(standup: standup))
    }

    standup.title = "Engineering"
    await store.send(.destination(.presented(.add(.set(\.$standup, standup))))) {
      $0.$destination[case: /StandupsList.Destination.State.add]?.standup.title = "Engineering"
    }

    await store.send(.confirmAddStandupButtonTapped) {
      $0.destination = nil
      $0.standups = [standup]
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
      )
    ) {
      StandupsList()
    } withDependencies: {
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
            Attendee(id: Attendee.ID(UUID(0)))
          ],
          title: "Design"
        )
      ]
    }
  }

  func testLoadingDataDecodingFailed() async throws {
    let store = TestStore(initialState: StandupsList.State()) {
      StandupsList()
    } withDependencies: {
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
    let store = TestStore(initialState: StandupsList.State()) {
      StandupsList()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.dataManager.load = { _ in
        struct FileNotFound: Error {}
        throw FileNotFound()
      }
    }

    XCTAssertEqual(store.state.destination, nil)
  }
}
