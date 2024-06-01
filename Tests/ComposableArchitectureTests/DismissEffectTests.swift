import ComposableArchitecture
import XCTest

final class DismissTests: XCTestCase {
  @MainActor
  func testDismissWithoutPresentationTools() async {
    let store = TestStore(initialState: .init()) {
      ParentFeature()
    }

    await store.send(.presentChild) {
      $0.childFeature = ChildFeature.State()
    }
    await store.send(.childFeature(.donePressed))
    await store.send(.childFeature(.donePressed))
  }

  @MainActor
  func testIsPresented_TestStore() async {
    let store = TestStore(initialState: Bool?.none) {
      Reduce<Bool?, Void> { state, _ in
        @Dependency(\.isPresented) var isPresented
        state = isPresented
        return .none
      }
    }

    await store.send(()) {
      $0 = false
    }
  }
}

@Reducer
private struct ChildFeature: Reducer {
  struct State: Equatable { }
  enum Action: Equatable {
    case donePressed
  }
  @Dependency(\.dismiss) var dismiss
  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .donePressed:
        return .run { send in
          await self.dismiss()
        }
      }
    }
  }
}

@Reducer
private struct ParentFeature: Reducer {
  struct State: Equatable {
    var childFeature: ChildFeature.State?
  }
  enum Action: Equatable {
    case presentChild
    case childFeature(ChildFeature.Action)
  }
  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .presentChild:
        state.childFeature = ChildFeature.State()
        return .none

      case .childFeature:
        return .none
      }
    }.ifLet(\.childFeature, action: \.childFeature) {
      ChildFeature()
    }
  }
}
