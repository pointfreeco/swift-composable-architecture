@_spi(Logging) import ComposableArchitecture
import SwiftUI
import XCTest

class ScopeLoggerTests: XCTestCase {
  @MainActor
  func testScoping() {
    #if DEBUG
      Logger.shared.isEnabled = true
      let store = Store(
        initialState: NavigationTestCaseView.Feature.State(
          path: StackState([
            BasicsView.Feature.State()
          ])
        )
      ) {
        NavigationTestCaseView.Feature()
      }
      let viewStore = ViewStore(store, observe: { $0 })
      let pathStore = store.scope(state: \.path, action: \.path)
      let elementStore = pathStore.scope(state: \.[id: 0]!, action: \.[id: 0])
      Logger.shared.clear()
      elementStore.send(.incrementButtonTapped)
      XCTAssertEqual(
        [],
        Logger.shared.logs
      )
      let _ = viewStore
      let _ = pathStore
      let _ = elementStore
    #endif
  }
}

struct NavigationTestCaseView {
  @Reducer
  struct Feature {
    struct State: Equatable {
      var path = StackState<BasicsView.Feature.State>()
    }
    enum Action {
      case path(StackActionOf<BasicsView.Feature>)
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
