import ComposableArchitecture
import XCTest

@MainActor
final class OnChangeReducerTests: BaseTCATestCase {
  func testOnChange() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {
        var count = 0
        var description = ""
      }
      enum Action: Equatable {
        case incrementButtonTapped
        case decrementButtonTapped
      }
      var body: some ReducerProtocolOf<Self> {
        Reduce { state, action in
          switch action {
          case .decrementButtonTapped:
            state.count -= 1
            return .none
          case .incrementButtonTapped:
            state.count += 1
            return .none
          }
        }
        .onChange(of: \.count) { oldValue, newValue in
          Reduce { state, action in
            state.description = String(repeating: "!", count: newValue)
            return newValue > 1 ? .send(.decrementButtonTapped) : .none
          }
        }
      }
    }
    let store = TestStore(initialState: Feature.State()) { Feature() }
    await store.send(.incrementButtonTapped) {
      $0.count = 1
      $0.description = "!"
    }
    await store.send(.incrementButtonTapped) {
      $0.count = 2
      $0.description = "!!"
    }
    await store.receive(.decrementButtonTapped) {
      $0.count = 1
      $0.description = "!"
    }
  }
}
