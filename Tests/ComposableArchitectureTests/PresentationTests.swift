import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class PresentationTests: XCTestCase {
  func testCancelEffectsOnDismissal() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.button1Tapped) {
      $0.child1 = Child1.State()
    }
    await store.send(.child1(.dismiss)) {
      $0.child1 = nil
    }
    // TODO: possible to not send this action if we detect it was already sent?
    await store.receive(.child1(.dismiss))
  }

  func testChildDismissing() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.button1Tapped) {
      $0.child1 = Child1.State()
    }
    await store.send(.child1(.presented(.closeButtonTapped)))
    await store.receive(.child1(.dismiss)) {
      $0.child1 = nil
    }
  }

  func testMultiplePresentations() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.button1Tapped) {
      $0.child1 = Child1.State()
    }
    await store.send(.button2Tapped) {
      $0.child2 = Child2.State()
    }
    await store.send(.child1(.presented(.closeButtonTapped)))
    await store.receive(.child1(.dismiss)) {
      $0.child1 = nil
    }
    await store.send(.child2(.presented(.closeButtonTapped)))
    await store.receive(.child2(.dismiss)) {
      $0.child2 = nil
    }
  }
}

private struct Feature: ReducerProtocol {
  struct State: Equatable {
    @PresentationStateOf<Child1> var child1
    @PresentationStateOf<Child2> var child2
  }
  enum Action: Equatable {
    case button1Tapped
    case button2Tapped
    case child1(PresentationActionOf<Child1>)
    case child2(PresentationActionOf<Child2>)
  }
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .button1Tapped:
        state.child1 = Child1.State()
        return .none
      case .button2Tapped:
        state.child2 = Child2.State()
        return .none
      case .child1:
        return .none
      case .child2:
        return .none
      }
    }
    .presentationDestination(\.$child1, action: /Action.child1) {
      Child1()
    }
    .presentationDestination(\.$child2, action: /Action.child2) {
      Child2()
    }
  }
}

private struct Child1: ReducerProtocol {
  struct State: Equatable {
  }
  enum Action: Equatable {
    case closeButtonTapped
    case onAppear
  }
  @Dependency(\.dismiss) var dismiss
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .closeButtonTapped:
      return .fireAndForget {
        await self.dismiss()
      }
    case .onAppear:
      return .run { _ in try await Task.never() }
    }
  }
}

private struct Child2: ReducerProtocol {
  struct State: Equatable {
  }
  enum Action: Equatable {
    case closeButtonTapped
    case onAppear
  }
  @Dependency(\.dismiss) var dismiss
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .closeButtonTapped:
      return .fireAndForget {
        await self.dismiss()
      }
    case .onAppear:
      return .run { _ in try await Task.never() }
    }
  }
}
