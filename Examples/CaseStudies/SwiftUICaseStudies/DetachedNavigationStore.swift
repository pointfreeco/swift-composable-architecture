import ComposableArchitecture
import SwiftUI

@Reducer
struct DetachedNavigationFeature {
  @ObservableState
  struct State {
    var path = NavigationPath()
    var sum = 0
  }
  enum Action {
    case childDelegate(ChildFeature.Action.Delegate)
    case setPath(NavigationPath)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .childDelegate(let action):
        switch action {
        case .done(let count):
          state.sum += count
          state.path.removeLast()
          return .none
        }
      case .setPath(let path):
        state.path = path
        return .none
      }
    }
  }
}

struct DetachedNavigationRoot: View {
  @Bindable var store: StoreOf<DetachedNavigationFeature>

  var body: some View {
    NavigationStack(path: $store.path.sending(\.setPath)) {
      Form {
        NavigationLink(value: 100) {
          Text("Go")
        }
        Text("Sum \(store.sum)")
      }
        .navigationDestination(for: Int.self) { int in
          ChildView(
            store: Store(
              initialState: DetachedNavigationFeature.ChildFeature.State(count: int)
            ) {
              DetachedNavigationFeature.ChildFeature()
              Reduce { state, action in
                if let delegateAction = action[case: \.delegate] {
                  store.send(.childDelegate(delegateAction))
                }
                return .none
              }
                //.delegate(\.delegate, to: \.childDelegate, on: store)
            }
          )
        }
    }
  }

  struct ChildView: View {
    @State var store: StoreOf<DetachedNavigationFeature.ChildFeature>

    var body: some View {
      Form {
        NavigationLink(value: store.count) {
          Text("Go to \(store.count)")
        }
        Button("Done") {
          store.send(.doneTapped)
        }
      }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
    }
  }
}

extension DetachedNavigationFeature {
  @Reducer
  struct ChildFeature {
    @ObservableState
    struct State: Hashable, Identifiable {
      let id = UUID()
      var count = 0
    }
    enum Action {
      case delegate(Delegate)
      case onAppear
      case onDisappear
      case doneTapped
      case timerTick
      enum Delegate {
        case done(Int)
      }
    }
    private enum CancelID: Hashable { case timer(UUID) }

    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .delegate:
          return .none
        case .doneTapped:
          return .send(.delegate(.done(state.count)))
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
}
