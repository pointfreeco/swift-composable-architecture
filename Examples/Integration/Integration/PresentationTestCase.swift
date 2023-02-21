import ComposableArchitecture
import SwiftUI

private struct PresentationTestCase: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var child: ChildFeature.State?
  }
  enum Action: Equatable, Sendable {
    case child(PresentationAction<ChildFeature.Action>)
    case childButtonTapped
  }

  var body: some ReducerProtocolOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .child(.presented(.parentSendDismissActionButtonTapped)):
        return .send(.child(.dismiss))
      case .child:
        return .none
      case .childButtonTapped:
        state.child = ChildFeature.State()
        return .none
      }
    }
    .presents(\.$child, action: /Action.child) {
      ChildFeature()
    }
  }
}

private struct ChildFeature: ReducerProtocol {
  struct State: Equatable {
    var count = 0
  }
  enum Action {
    case childDismissButtonTapped
    case incrementButtonTapped
    case parentSendDismissActionButtonTapped
  }
  @Dependency(\.dismiss) var dismiss
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .childDismissButtonTapped:
      return .fireAndForget { await self.dismiss() }
    case .incrementButtonTapped:
      state.count += 1
      return .none
    case .parentSendDismissActionButtonTapped:
      return .none
    }
  }
}

struct PresentationTestCaseView: View {
  private let store = Store(
    initialState: PresentationTestCase.State(),
    reducer: PresentationTestCase()
  )

  var body: some View {
    WithViewStore(self.store, observe: { _ in () }, removeDuplicates: ==) { viewStore in
      Button("Open child") {
        viewStore.send(.childButtonTapped)
      }
    }
    .sheet(
      store: self.store.scope(state: \.$child, action: PresentationTestCase.Action.child)
    ) { store in
      ChildView(store: store)
    }
  }
}

private struct ChildView: View {
  let store: StoreOf<ChildFeature>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {
        Text("Count: \(viewStore.count)")
        Button("Child dismiss") {
          viewStore.send(.childDismissButtonTapped)
        }
        Button("Increment") {
          viewStore.send(.incrementButtonTapped)
        }
        Button("Parent dismiss") {
          viewStore.send(.parentSendDismissActionButtonTapped)
        }
      }
    }
  }
}
