@preconcurrency import ComposableArchitecture
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
    .ifLet(\.$child, action: /Action.child) {
      ChildFeature()
    }
  }
}

private struct ChildFeature: ReducerProtocol {
  struct State: Equatable, Identifiable {
    var id = UUID()
    var count = 0
  }
  enum Action {
    case childDismissButtonTapped
    case incrementButtonTapped
    case parentSendDismissActionButtonTapped
    case resetIdentity
    case response
    case startButtonTapped
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
    case .resetIdentity:
      state.id = UUID()
      return .none
    case .response:
      state.count = 999
      return .none
    case .startButtonTapped:
      state.count += 1
      return .run { send in
        try await Task.sleep(for: .seconds(3))
        await send(.response)
      }
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
        Button("Start effect") {
          viewStore.send(.startButtonTapped)
        }
        Button("Reset identity") {
          viewStore.send(.resetIdentity)
        }
      }
    }
  }
}
