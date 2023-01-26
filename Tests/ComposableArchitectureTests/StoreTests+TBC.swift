import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

// TBC additions
extension StoreTests {
    func testScopingRemovesDuplicatesWithProvidedClosure() {
        struct State: Equatable {
          var place: String
        }
        enum Action: Equatable {
          case noop
          case updatePlace(String)
        }
        let parentStore = Store<State, Action>(
          initialState: .init(place: "New York"),
          reducer: Reduce { state, action in
              switch action {
              case .noop:
                return .none
              case let .updatePlace(place):
                state.place = place
                return .none
              }
            }
        )
        let childStore: Store<State, Action> = parentStore.scope(
          state: { $0 },
          action: { $0 },
          removeDuplicates: ==
        )
        var scopeCount: Int = 0
        let leafStore: Store<State, Action> = childStore.scope(
          state: { parentState -> State in
            scopeCount += 1
            return parentState
          },
          action: { $0 },
          removeDuplicates: ==
        )
        XCTAssertEqual(scopeCount, 1)
        _ = parentStore.send(.noop)
        XCTAssertEqual(scopeCount, 1)
        _ = parentStore.send(.updatePlace("Washington"))
        XCTAssertEqual(scopeCount, 2)
        _ = childStore.send(.noop)
        _ = leafStore.send(.noop)
      }
}
