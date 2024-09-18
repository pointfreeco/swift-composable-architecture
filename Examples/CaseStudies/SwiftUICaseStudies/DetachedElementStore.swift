import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct ChildFeature {
  @ObservableState
  struct State: Identifiable {
    let id = UUID()
    var count = 0
  }
  enum Action {
    case delegate(Delegate)
    case onAppear
    case onDisappear
    case timerTick
    enum Delegate {
    }
    enum Callback {
      case refresh
    }
  }
  private enum CancelID: Hashable { case timer(UUID) }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { send in
          while true {
            try await Task.sleep(for: .seconds(1))
            await send(.timerTick)
          }
        }
        .cancellable(id: CancelID.timer(state.id))
      case .onDisappear:
        return .cancel(id: CancelID.timer(state.id))
      case .timerTick:
        state.count += 1
        return .none
      }
    }
  }
}

@Reducer
struct ListFeature {
  @ObservableState
  struct State {
    var children: IdentifiedArrayOf<ChildFeature.State> = []
  }

  enum Action {
    case detachedChildren(IdentifiedAction<UUID, Never>)

    case children(IdentifiedAction<UUID, ChildFeature.Action>)
  }

  //@Dependency(\.child)

  // child(.refresh)
  // store.child.send(…)

  var body: some ReducerOf<Self> {
    EmptyReducer()
      .forEach(\.children, action: \.children) {
        ChildFeature()
      }
  }
}

struct ListView: View {
  @State var isShowingDetachedList = false
  let store: StoreOf<ListFeature>

  var body: some View {
    if isShowingDetachedList {
      List {
        Button("Integrate") { isShowingDetachedList = false }
        ForEach(store.scope(state: \.children, action: \.detachedChildren)) { store in
          ChildView(
            store: store.detached(delegate: \.never) {
              ChildFeature()
//                ._printChanges()
            }
          )
        }
      }
    } else {
      List {
        Button("Detach") { isShowingDetachedList = true }
        ForEach(store.scope(state: \.children, action: \.children)) { store in
          ChildView(store: store)
        }
      }
    }
  }
}

struct ChildView: View {
  let store: StoreOf<ChildFeature>

  var body: some View {
    Text(store.count.description)
      .onAppear { store.send(.onAppear) }
      .onDisappear { store.send(.onDisappear) }
  }
}

#Preview {
  ListView(
    store: Store(
      initialState: ListFeature.State(
        children: IdentifiedArray(uniqueElements: (1...1_000).map { idx in
          ChildFeature.State(count: idx)
        })
      )
    ) {
      ListFeature()
    }
  )
}
