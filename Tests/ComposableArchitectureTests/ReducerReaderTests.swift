import ComposableArchitecture
import XCTest

@MainActor
final class StateReaderTests: XCTestCase {
  func testDependenciesPropagate() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {}

      enum Action: Equatable {
        case tap
      }

      @Dependency(\.date.now) var now

      var body: some ReducerProtocolOf<Self> {
        ReducerReader { _, _ in
          let _ = self.now
        }
      }
    }

    let store = TestStore(initialState: Feature.State(), reducer: Feature()) {
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
    }
    await store.send(.tap)
  }
}
