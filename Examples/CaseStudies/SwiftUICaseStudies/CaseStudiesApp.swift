import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      ParentView(store: Store(initialState: Parent.State(), reducer: Parent()))
//      RootView(
//        store: Store(
//          initialState: Root.State(),
//          reducer: Root()
//            .signpost()
//            ._printChanges()
//        )
//      )
    }
  }
}


struct Parent: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var child = Child.State()
  }
  enum Action: Equatable {
    case child(Child.Action)
    case tap
  }
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .tap:
        state.count = Int.random(in: 0..<100)
        return .none
      default:
        return .none
      }
    }
    Scope(state: \.child, action: /Action.child) {
      Child()
    }
  }
}
struct Child: ReducerProtocol {
  struct State: Equatable {
    var count = 0
  }
  enum Action: Equatable {
    case tap
  }
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .tap:
        state.count = Int.random(in: 0..<100)
        return .none
      }
    }
  }
}
struct ParentView: View {
  let store: StoreOf<Parent>
  var body: some View {
    WithViewStore(store, observe: \.count) { viewStore in
      let _ = print("ParentView.WithViewStore.body")
      ZStack {
        Color.red
        VStack {
          ScopeStore(self.store, state: \.child, action: Parent.Action.child) { store in
            ChildView(store: store)
          }
//          ChildView(store: self.store.scope(state: \.child, action: Parent.Action.child))
          Text("ContentView-----\(viewStore.state)")
        }

      }
      .onTapGesture {
        viewStore.send(.tap)
      }
    }
  }
}

struct ChildView: View {
  let store: StoreOf<Child>

  var body: some View {
    let _ = print("ChildView.body")
    WithViewStore(store, observe: { $0 }) { viewStore in
      let _ = print("ChildView.WithViewStore.body")
      Text("11  --- \(viewStore.count)")
        .onTapGesture {
          viewStore.send(.tap)
        }
    }
  }
}

struct ScopeStore<ParentState, ParentAction, ChildState, ChildAction, Content: View>: View {
  @State var scopedStore: Store<ChildState, ChildAction>
  let content: (Store<ChildState, ChildAction>) -> Content

  init(
    _ store: Store<ParentState, ParentAction>,
    state: @escaping (ParentState) -> ChildState,
    action: @escaping (ChildAction) -> ParentAction,
    @ViewBuilder content: @escaping (Store<ChildState, ChildAction>) -> Content
  ) {
    self._scopedStore = State(wrappedValue: store.scope(state: state, action: action))
    self.content = content
  }

  var body: some View {
    let _ = print("ScopeView.body")
    self.content(self.scopedStore)
  }
}
