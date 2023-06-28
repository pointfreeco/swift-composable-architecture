import ComposableArchitecture
import SwiftUI

struct SwitchStoreTestCase: ReducerProtocol {
  struct Screen: ReducerProtocol {
    struct State: Equatable {
      var count = 0
    }
    enum Action {
      case decrementButtonTapped
      case incrementButtonTapped
    }
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        return .none
      case .incrementButtonTapped:
        state.count += 1
        return .none
      }
    }
  }

  enum State: Equatable {
    case screenA(Screen.State = .init())
    case screenB(Screen.State = .init())
  }
  enum Action {
    case screenA(Screen.Action)
    case screenB(Screen.Action)
    case swap
  }

  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch (state, action) {
      case (_, .screenA), (_, .screenB):
        return .none
      case (.screenA, .swap):
        state = .screenB(Screen.State())
        return .none
      case (.screenB, .swap):
        state = .screenA(Screen.State())
        return .none
      }
    }
    .ifCaseLet(/State.screenA, action: /Action.screenA) {
      Screen()
    }
    .ifCaseLet(/State.screenB, action: /Action.screenB) {
      Screen()
    }
  }
}

struct SwitchStoreTestCaseView: View {
  let store = Store(initialState: .screenA()) {
    SwitchStoreTestCase()
  }

  var body: some View {
    Button("Swap") { self.store.send(.swap) }
    SwitchStore(self.store) {
      switch $0 {
      case .screenA:
        CaseLet(
          /SwitchStoreTestCase.State.screenA, action: SwitchStoreTestCase.Action.screenA
        ) { store in
          ScreenView(store: store)
        }
      case .screenB:
        // Simulate copy-paste error:
        CaseLet(
          /SwitchStoreTestCase.State.screenA, action: SwitchStoreTestCase.Action.screenA
        ) { store in
          ScreenView(store: store)
        }
      }
    }
  }

  struct ScreenView: View {
    let store: StoreOf<SwitchStoreTestCase.Screen>

    var body: some View {
      WithViewStore(self.store, observe: { $0 }) { viewStore in
        HStack {
          Button("-") { viewStore.send(.decrementButtonTapped) }
          Text("\(viewStore.count)")
          Button("+") { viewStore.send(.decrementButtonTapped) }
        }
      }
    }
  }
}
