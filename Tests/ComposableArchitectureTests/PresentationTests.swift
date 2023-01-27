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

    await store.send(.child1Tapped) {
      $0.child1 = Child.State()
    }
    await store.send(.child1(.presented(.onAppear)))
    await store.send(.child1(.dismiss)) {
      $0.child1 = nil
    }
  }

  func testCancelEffectsOnDismissal_FromGrandparent() async {
    // TODO: This test currently fails, but is there anything we can do to make it pass? Probably
    // not without a reducer graph system.
//    XCTExpectFailure { _ in
//      true
//    }

    struct Grandparent: ReducerProtocol {
      struct State: Equatable {
        var feature: Feature.State
      }
      enum Action: Equatable {
        case feature(Feature.Action)
        case tap
      }
      var body: some ReducerProtocolOf<Self> {
        Scope(state: \.feature, action: /Action.feature) {
          Feature()
        }
        Reduce<State, Action> { state, action in
          switch action {
          case .feature:
            return .none
          case .tap:

            // TODO: try this
//            let cancellation = state.feature.$child1.dismiss()
//            return .merge(cancelleration)

            // logic
            // TODO: this is also a possibility
            return .send(.feature(.child1(.dismiss)))

            // logic
            state.feature.child1 = nil
            // logic
            return .none
          }
        }
      }
    }

    let store = TestStore(
      initialState: Grandparent.State(feature: Feature.State()),
      reducer: Grandparent()
    )

    await store.send(.feature(.child1Tapped)) {
      $0.feature.child1 = Child.State()
    }
    await store.send(.feature(.child1(.presented(.onAppear))))
    await store.send(.tap)
    await store.receive(.feature(.child1(.dismiss))) {
      $0.feature.child1 = nil
    }
  }

  func testCancelEffectsOnDismissal_ChildHydratedOnLaunch() async {
    let store = TestStore(
      initialState: Feature.State(child1: .presented(id: 0, Child.State())),
      reducer: Feature()
    )

    await store.send(.child1(.presented(.onAppear)))
    await store.send(.child1(.dismiss)) {
      $0.child1 = nil
    }
  }

  func testChildDismissing() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.child1Tapped) {
      $0.child1 = Child.State()
      //$0.child1 = Child.State()
    }
    await store.send(.child1(.presented(.closeButtonTapped)))
    await store.receive(.child1(.dismiss)) {
      $0.child1 = nil
    }
  }

  func testChildDismissing_ChildHydratedOnLaunch() async {
    // TODO: This test fails, but it should pass
    XCTExpectFailure()

    let store = TestStore(
      initialState: Feature.State(child1: .presented(id: 0, Child.State())),
      reducer: Feature()
    )

    await store.send(.child1(.presented(.closeButtonTapped)))
    await store.receive(.child1(.dismiss)) {
      $0.child1 = nil
    }
  }

  func testPresentWithNil() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.child1(.present())) {
      $0.child1 = Child.State()
    }
    await store.send(.child1(.dismiss)) {
      $0.child1 = nil
    }
  }

  func testPresentWithState() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.child1(.present(id: UUID(), Child.State(count: 42)))) {
      $0.child1 = Child.State(count: 42)
    }
    await store.send(.child1(.dismiss)) {
      $0.child1 = nil
    }
  }

  func testChildEffect() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    store.dependencies.mainQueue = .immediate

    await store.send(.child1(.present(id: UUID(), nil))) {
      $0.child1 = Child.State()
    }
    await store.send(.child1(.presented(.performButtonTapped)))
    await store.receive(.child1(.presented(.response(1)))) {
      $0.child1?.count = 1
    }
    await store.send(.child1(.dismiss)) {
      $0.child1 = nil
    }
  }

  func testMultiplePresentations() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    await store.send(.child1Tapped) {
      $0.child1 = Child.State()
    }
    await store.send(.child2Tapped) {
      $0.child2 = Child.State()
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

  func testWarnWhenSendingActionToNilChildState() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {
        @PresentationState<Int> var child
      }
      enum Action {
        case child(PresentationAction<Int, Void>)
      }
      var body: some ReducerProtocol<State, Action> {
        EmptyReducer()
          .presentationDestination(\.$child, action: /Action.child) {}
      }
    }
    let line = #line - 3

    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )

    XCTExpectFailure {
      $0.compactDescription == """
        A "presentationDestination" at "ComposableArchitectureTests/PresentationTests.swift:\
        \(line)" received a destination action when destination state was absent. …

          Action:
            PresentationTests.Feature.Action.child(.presented)

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set destination state to "nil" before this reducer ran. This reducer \
        must run before any other reducer sets destination state to "nil". This ensures that \
        destination reducers can handle their actions while their state is still present.

        • This action was sent to the store while destination state was "nil". Make sure that \
        actions for this reducer can only be sent from a view store when state is present, or from \
        effects that start from this reducer. In SwiftUI applications, use a Composable \
        Architecture view modifier like "sheet(store:…)".
        """
    }

    await store.send(.child(.presented(())))
  }

  func testResetStateCancelsEffects() async {
    let mainQueue = DispatchQueue.test
    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
    )
    store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()
    store.dependencies.uuid = .incrementing

    await store.send(.child1Tapped) {
      $0.child1 = Child.State()
    }
    await store.send(.child1(.presented(.performButtonTapped)))
    await store.send(.reset1ButtonTapped)
    await mainQueue.run()
    await store.send(.child1(.dismiss)) {
      $0.child1 = nil
    }
  }

  func testFoo() async {
    let store = TestStore(
      initialState: Feature.State(),
      reducer: EmptyReducer<Feature.State, Feature.Action>()
        .presentationDestination(\.$child1, action: /Feature.Action.child1) {}
    )
    let line = #line - 2

    // TODO: This does not fail but it should?
    XCTExpectFailure {
      $0.compactDescription == """
        A ".present" action was sent with "nil" state at "\(#fileID):\(line)" but the destination \
        state was not hydrated to something non-nil: …

          Action:
            Feature.Action.child1(.present(id:, _:))

        This is generally considered an application logic error. To fix, match on the ".present" \
        action in the parent reducer in order to hydrate the destination state to something non-nil.
        """
    }

    await store.send(.child1(.present(id: UUID())))
  }
}

private struct Feature: ReducerProtocol {
  struct State: Equatable {
    @PresentationStateOf<Child> var child1
    @PresentationStateOf<Child> var child2
    @PresentationStateOf<Child> var unpresentable
  }
  enum Action: Equatable {
    case child1Tapped
    case child2Tapped
    case child1(PresentationActionOf<Child>)
    case child2(PresentationActionOf<Child>)
    case unpresentable(PresentationActionOf<Child>)
    case reset1ButtonTapped
  }
  @Dependency(\.uuid) var uuid
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .child1Tapped:
        state.child1 = Child.State()
        return .none

      case .child2Tapped:
        state.child2 = Child.State()
        return .none

      case .child1(.present(id: _, .none)):
        state.child1 = Child.State()
        return .none

      case let .child1(.present(id: _, .some(childState))):
        state.child1 = childState
        return .none

      case .child1:
        return .none

      case .child2(.present(id: _, .none)):
        state.child2 = Child.State()
        return .none

      case let .child2(.present(id: _, .some(childState))):
        state.child2 = childState
        return .none

      case .child2:
        return .none

      case .unpresentable:
        return .none

      case .reset1ButtonTapped:
        state.$child1 = .presented(id: self.uuid(), Child.State())
        return .none
      }
    }
    .presentationDestination(\.$child1, action: /Action.child1) {
      Child()
    }
    .presentationDestination(\.$child2, action: /Action.child2) {
      Child()
    }
    .presentationDestination(\.$unpresentable, action: /Action.unpresentable) {
      Child()
    }
  }
}

private struct Child: ReducerProtocol {
  struct State: Equatable {
    var count = 0
  }
  enum Action: Equatable {
    case closeButtonTapped
    case onAppear
    case performButtonTapped
    case response(Int)
  }
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.mainQueue) var mainQueue
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .closeButtonTapped:
      return .fireAndForget {
        await self.dismiss()
      }

    case .onAppear:
      return .run { _ in try await Task.never() }

    case .performButtonTapped:
      return .run { [count = state.count] send in
        try await self.mainQueue.sleep(for: .seconds(1))
        await send(.response(count + 1))
      }

    case let .response(value):
      state.count = value
      return .none
    }
  }
}
