import ComposableArchitecture
import XCTest

@MainActor
final class DependencyKeyWritingReducerTests: XCTestCase {
  func testWritingFusionOrder() async {
    struct Feature: ReducerProtocol {
      @Dependency(\.date) var date
      struct State: Equatable {
        var currentDate = Date()
      }
      enum Action {
        case tap
      }
      func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .tap:
          state.currentDate = self.date()
          return .none
        }
      }
    }

    let reducer = Feature()
      .dependency(\.date, ConstantDateGenerator(Date(timeIntervalSince1970: 42)))
      .dependency(\.date, ConstantDateGenerator(Date(timeIntervalSince1970: 1729)))

    let store = TestStore(
      initialState: Feature.State(),
      reducer: reducer
    )

    await store.send(.tap) {
      $0.currentDate = Date(timeIntervalSince1970: 42)
    }
  }

  func testWritingOrder() async {
    struct Feature: ReducerProtocol {
      @Dependency(\.date) var date
      struct State: Equatable {
        var currentDate = Date()
      }
      enum Action {
        case tap
      }
      func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .tap:
          state.currentDate = self.date()
          return .none
        }
      }
    }

    let reducer = CombineReducers {
      Feature()
        .dependency(\.date, ConstantDateGenerator(Date(timeIntervalSince1970: 42)))
    }
    .dependency(\.date, ConstantDateGenerator(Date(timeIntervalSince1970: 1729)))

    let store = TestStore(
      initialState: Feature.State(),
      reducer: reducer
    )

    await store.send(.tap) {
      $0.currentDate = Date(timeIntervalSince1970: 42)
    }
  }
}
