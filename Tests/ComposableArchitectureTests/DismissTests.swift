import ComposableArchitecture
import XCTest

@MainActor
final class DismissTests: XCTestCase {
  func testDismissInNonPresentationContext() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {}
      enum Action { case tap }
      @Dependency(\.dismiss) var dismiss

      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        return .run { _ in
          await self.dismiss()
        }
      }
    }
    let line = #line - 4

    XCTExpectFailure {
      $0.compactDescription == """
        A reducer requested dismissal at "ComposableArchitectureTests/DismissTests.swift:\(line)", \
        but couldn't be dismissed. …

        This is generally considered an application logic error, and can happen when a reducer \
        assumes it runs in a presentation destination. If a reducer can run at both the root level \
        of an application, as well as in a presentation destination, use \
        @Dependency(\\.isPresented) to determine if the reducer is being presented before calling \
        @Dependency(\\.dismiss).
        """
    }

    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.tap).finish()
  }

  func testIsPresentedInNonPresentationContext() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {
        var isPresented: Bool?
      }
      enum Action { case tap }
      @Dependency(\.isPresented) var isPresented

      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        state.isPresented = self.isPresented
        return .none
      }
    }

    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.tap) {
      $0.isPresented = false
    }
  }

  func testIsPresentedInPresentationContext() async {
    let store = TestStore(
      initialState: SimpleParentFeature.State(),
      reducer: SimpleParentFeature()
    )

    await store.send(.childTapped) {
      $0.child = SimpleChildFeature.State()
    }

    await store.send(.child(.presented(.onAppear))) {
      $0.child = try XCTUnwrap($0.child)
      $0.child?.isPresented = true
    }

    await store.send(.child(.dismiss)) {
      $0.child = nil
    }
  }

  func testIsPresentedInDeepLinkedContext() async {
    let store = TestStore(
      initialState: SimpleParentFeature.State(
        child: .presented(
          id: UUID(),
          SimpleChildFeature.State()
        )
      ),
      reducer: SimpleParentFeature()
    )

    await store.send(.child(.presented(.onAppear))) {
      $0.child = try XCTUnwrap($0.child)
      $0.child?.isPresented = true
    }
  }
}

private struct SimpleParentFeature: ReducerProtocol {
  struct State: Equatable {
    @PresentationStateOf<SimpleChildFeature> var child
  }
  enum Action: Equatable {
    case childTapped
    case child(PresentationActionOf<SimpleChildFeature>)
  }
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .childTapped:
        state.child = SimpleChildFeature.State()
        return .none
      case .child:
        return .none
      }
    }
    .presentationDestination(\.$child, action: /Action.child) {
      SimpleChildFeature()
    }
  }
}

private struct SimpleChildFeature: ReducerProtocol {
  struct State: Equatable {
    var isPresented: Bool?
  }
  enum Action: Equatable {
    case onAppear
  }
  @Dependency(\.isPresented) var isPresented
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    state.isPresented = self.isPresented
    return .none
  }
}

