import ComposableArchitecture
import XCTest

@testable import SyncUps

@MainActor
final class SyncUpsListTests: XCTestCase {
  func testAdd() async throws {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock()
      $0.uuid = .incrementing
    }

    var syncUp = SyncUp(
      id: SyncUp.ID(UUID(0)),
      attendees: [
        Attendee(id: Attendee.ID(UUID(1)))
      ]
    )
    await store.send(.addSyncUpButtonTapped) {
      $0.destination = .add(SyncUpForm.State(syncUp: syncUp))
    }

    syncUp.title = "Engineering"
    await store.send(.destination(.presented(.add(.set(\.syncUp, syncUp))))) {
      $0.$destination[case: \.add]?.syncUp.title = "Engineering"
    }

    await store.send(.confirmAddSyncUpButtonTapped) {
      $0.destination = nil
      $0.syncUps = [syncUp]
    }
  }

  func testAdd_ValidatedAttendees() async throws {
    @Dependency(\.uuid) var uuid

    let store = TestStore(
      initialState: SyncUpsList.State(
        destination: .add(
          SyncUpForm.State(
            syncUp: SyncUp(
              id: SyncUp.ID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
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
      SyncUpsList()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock()
      $0.uuid = .incrementing
    }

    await store.send(.confirmAddSyncUpButtonTapped) {
      $0.destination = nil
      $0.syncUps = [
        SyncUp(
          id: SyncUp.ID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
          attendees: [
            Attendee(id: Attendee.ID(UUID(0)))
          ],
          title: "Design"
        )
      ]
    }
  }

  func testLoadingDataDecodingFailed() async throws {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock(
        initialData: Data("!@#$ BAD DATA %^&*()".utf8)
      )
    }

    XCTAssertEqual(store.state.destination, .alert(.dataFailedToLoad))

    await store.send(.destination(.presented(.alert(.confirmLoadMockData)))) {
      $0.destination = nil
      $0.syncUps = [
        .mock,
        .designMock,
        .engineeringMock,
      ]
    }
  }

  func testLoadingDataFileNotFound() async throws {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.dataManager.load = { @Sendable _ in
        struct FileNotFound: Error {}
        throw FileNotFound()
      }
    }

    XCTAssertEqual(store.state.destination, nil)
  }
}
