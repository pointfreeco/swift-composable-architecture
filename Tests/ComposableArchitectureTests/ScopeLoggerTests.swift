import XCTest
import SwiftUI
@_spi(Logging) import ComposableArchitecture

class ScopeLoggerTests: XCTestCase {
  func testScoping() {
    let store = Store(initialState: NavigationTestCaseView.Feature.State()) {
      NavigationTestCaseView.Feature()
    }
    store.send(.path(.push(id: 0, state: BasicsView.Feature.State())))
    Logger.shared.clear()
    store.send(.path(.element(id: 0, action: .incrementButtonTapped)))
    XCTAssertEqual(
      [],
      Logger.shared.logs
    )
  }
}

struct NavigationTestCaseView {
  @Reducer
  struct Feature {
    struct State: Equatable {
      var path = StackState<BasicsView.Feature.State>()
    }
    enum Action {
      case path(StackAction<BasicsView.Feature.State, BasicsView.Feature.Action>)
    }
    var body: some ReducerOf<Self> {
      EmptyReducer()
      .forEach(\.path, action: \.path) {
        BasicsView.Feature()
      }
    }
  }
}

struct BasicsView {
  @Reducer
  struct Feature {
    struct State: Equatable, Identifiable {
      let id = UUID()
      var count = 0
    }
    enum Action {
      case decrementButtonTapped
      case dismissButtonTapped
      case incrementButtonTapped
    }
    @Dependency(\.dismiss) var dismiss
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .decrementButtonTapped:
          state.count -= 1
          return .none
        case .dismissButtonTapped:
          return .run { _ in await self.dismiss() }
        case .incrementButtonTapped:
          state.count += 1
          return .none
        }
      }
    }
  }
}
