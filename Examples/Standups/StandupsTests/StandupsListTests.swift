import ComposableArchitecture
import XCTest

@testable import Standups

@MainActor
final class StandupsListTests: XCTestCase {
  // TODO: why is this failing??
  func testAdd() async throws {
    let store = TestStore(
      initialState: StandupsList.State(),
      reducer: StandupsList()
    )

    store.dependencies.continuousClock = ImmediateClock()
    store.dependencies.dataManager.save = { _, _ in }
    store.dependencies.uuid = .incrementing

    await store.send(.addStandupButtonTapped) {
      $0.destination = .add(
        EditStandup.State(
          standup: Standup(id: Standup.ID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        )
      )
    }

    await store.send(.destination(.presented(.add(.binding(.set(\.$standup.title, "Engineering")))))) {
      try (/StandupsList.Destinations.State.add).modify(&$0.destination) {
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
    let store = TestStore(
      initialState: StandupsList.State(
        destination: .add(
          EditStandup.State(
            standup: Standup(
              id: Standup.ID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
              attendees: [
                Attendee(id: Attendee.ID(), name: ""),
                Attendee(id: Attendee.ID(), name: "    "),
              ],
              title: "Design"
            )
          )
        )
      ),
      reducer: StandupsList()
    )

    store.dependencies.continuousClock = ImmediateClock()
    store.dependencies.dataManager.save = { _, _ in }
    store.dependencies.uuid = .incrementing

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

  func testDelete() async throws {
    let standup = Standup.mock

    let store = TestStore(
      initialState: StandupsList.State(),
      reducer: StandupsList()
    )

    store.dependencies.continuousClock = ImmediateClock()
    store.dependencies.dataManager = .mock(
      initialData: try JSONEncoder().encode([standup])
    )

    await store.send(.standupTapped(id: standup.id)) {
      $0.$path[id: 0] = .detail(StandupDetail.State(standup: standup))

      print($0.path)
      print($0.path.count)
      print("~!!")

      // TODO: look into why this fails
//      $0.path = [
//        .detail(StandupDetail.State(standup: standup))
//      ]
    }

    print(store.state.path.count)
    print("!!")

    await store.send(.path(.element(id: 0, .detail(.deleteButtonTapped)))) {
      try (/StandupsList.Stack.State.detail).modify(&$0.$path[id: 0]) {
        $0.destination = .alert(.deleteStandup)
      }
    }

    await store.send(.path(.element(id: 0, .detail(.destination(.presented(.alert(.confirmDeletion))))))) {
      try (/StandupsList.Stack.State.detail).modify(&$0.path[0]) {
        $0.destination = nil
      }
    }

    await store.receive(.path(.element(id: 0, .detail(.delegate(.deleteStandup))))) {
      $0.path = []
      $0.standups = []
    }
  }

  func testDetailEdit() async throws {
    let standup = Standup.mock

    let store = TestStore(
      initialState: StandupsList.State(),
      reducer: StandupsList()
    )

    store.dependencies.continuousClock = ImmediateClock()
    store.dependencies.dataManager = .mock(
      initialData: try JSONEncoder().encode([standup])
    )
    let savedData = LockIsolated(Data?.none)
    store.dependencies.dataManager.save = { data, _ in savedData.setValue(data) }

    await store.send(.standupTapped(id: standup.id)) {
      $0.$path[id: 0] = .detail(StandupDetail.State(standup: standup))
    }

    await store.send(.path(.element(id: 0, .detail(.editButtonTapped)))) {
      try (/StandupsList.Stack.State.detail).modify(&$0.path[0]) {
        $0.destination = .edit(EditStandup.State(standup: standup))
      }
    }

    await store.send(.path(.element(id: 0, .detail(.destination(.presented(.edit(.binding(.set(\.$standup.title, "Blob"))))))))) {
      try (/StandupsList.Stack.State.detail).modify(&$0.path[0]) {
        try (/StandupDetail.Destinations.State.edit).modify(&$0.destination) {
          $0.standup.title = "Blob"
        }
      }
    }

    await store.send(.path(.element(id: 0, .detail(.doneEditingButtonTapped)))) {
      try (/StandupsList.Stack.State.detail).modify(&$0.path[0]) {
        $0.destination = nil
        $0.standup.title = "Blob"
      }
      $0.standups[0].title = "Blob"
    }

    await store.send(.path(.dismiss(id: 0))) {
      $0.path = []
    }
  }

  func testLoadingDataDecodingFailed() async throws {
    let store = TestStore(
      initialState: StandupsList.State(),
      reducer: StandupsList()
    )

    store.dependencies.continuousClock = ImmediateClock()
    store.dependencies.dataManager = .mock(
      initialData: Data("!@#$ BAD DATA %^&*()".utf8)
    )

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
    )

    store.dependencies.continuousClock = ImmediateClock()
    store.dependencies.dataManager.load = { _ in
      struct FileNotFound: Error {}
      throw FileNotFound()
    }

    XCTAssertEqual(store.state.destination, nil)
  }
}
