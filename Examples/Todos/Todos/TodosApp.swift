import ComposableArchitecture
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(
        store: Store(initialState: Todos.State()) {
          Todos()._printChanges()
        }
      )
//      ParentView()
//      CounterView(
//        store: Store2(initialState: Counter.State()) {
//          Counter()
//        }
//      )
//      NavigationStack {
//        ListView()
//      }
    }
  }
}



import Combine

private class RootStore {
  fileprivate let didSet = PassthroughSubject<Void, Never>()
  private(set) var state: Any {
    didSet {
      self.didSet.send()
    }
  }
  private let reducer: any Reducer

  init<State, Action>(
    initialState: State,
    reducer: some Reducer<State, Action>
  ) {
    self.state = initialState
    self.reducer = reducer
  }

  func send(_ action: Any) {
    func open<State, Action>(reducer: some Reducer<State, Action>) {
      _ = reducer.reduce(into: &self[cast: State.self], action: action as! Action)
    }
    open(reducer: self.reducer)
  }

  subscript<Value>(cast type: Value.Type = Value.self) -> Value {
    get { self.state as! Value }
    set { self.state = newValue }
  }
}

final class Store2<State, Action> {
  private let actionKeyPath: Case<Action>
  fileprivate var rootStore: RootStore
  private let stateKeyPath: AnyKeyPath

  private init(
    actionKeyPath: Case<Action>,
    rootStore: RootStore,
    stateKeyPath: AnyKeyPath
  ) {
    self.rootStore = rootStore
    self.actionKeyPath = actionKeyPath
    self.stateKeyPath = stateKeyPath
  }

  func send(_ action: Action) {
    self.rootStore.send(self.actionKeyPath.embed(action))
  }


  var state: State {
    self.rootStore.state[keyPath: self.stateKeyPath] as! State
  }
  subscript<Member>(dynamicMember keyPath: KeyPath<State, Member>) -> Member {
    self.state[keyPath: keyPath]
  }

  convenience init(
    initialState: State,
    @ReducerBuilder<State, Action> reducer: () -> some Reducer<State, Action>
  ) {
    let rootStore = RootStore(
      initialState: initialState,
      reducer: reducer()
    )
    self.init(
      actionKeyPath: Case<Action>(),
      rootStore: rootStore,
      stateKeyPath: \State.self
    )
  }

  func scope<ChildState, ChildAction>(
    state: KeyPath<State, ChildState>,
    action actionCP: CaseKeyPath<Action, ChildAction>
  ) -> Store2<ChildState, ChildAction> {
    return Store2<ChildState, ChildAction>(
      actionKeyPath: self.actionKeyPath[keyPath: actionCP],
      rootStore: self.rootStore,
      stateKeyPath: self.stateKeyPath.appending(path: state)!
    )
  }
}

class ViewStore2<State: Equatable, Action>: ObservableObject {
  let store: Store2<State, Action>
  var cancellable: AnyCancellable?

  init(store: Store2<State, Action>) {
    self.store = store

    var previous = store.state
    self.cancellable = store.rootStore.didSet
      .removeDuplicates { [weak self] _, _ in
        guard let self else { return true }
        defer { previous = self.store.state }
        return self.store.state == previous
      }
      .sink { [weak self] in
        self?.objectWillChange.send()
      }
  }
}

@Reducer
struct Parent {
  struct State: Equatable {
    var child1 = Counter.State()
    var child2 = Counter.State()
  }
  enum Action {
    case child1(Counter.Action)
    case child2(Counter.Action)
  }
  var body: some ReducerOf<Self> {
    Scope(state: \.child1, action: \.child1) { Counter() }
    Scope(state: \.child2, action: \.child2) { Counter() }
  }
}

struct ParentView: View {
  let store = Store2(initialState: Parent.State()) {
    Parent()
  }
  var body: some View {
    Form {
      Section {
        CounterView(store: store.scope(state: \.child1, action: \.child1))
      }
      Section {
        CounterView(store: store.scope(state: \.child2, action: \.child2))
      }
    }
  }
}

@Reducer
struct Counter {
  struct State: Equatable, Identifiable {
    let id = UUID()
    var _count = 0
    var count: Int {
      get {
        _count
      }
      set { _count  = newValue }
    }
  }
  enum Action { case incr, onTask }
  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    state.count += 1
    return .none
  }
}
import SwiftUI
struct CounterView: View {
  let store: Store2<Counter.State, Counter.Action>
  @ObservedObject var viewStore: ViewStore2<Counter.State, Counter.Action>

  init(store: Store2<Counter.State, Counter.Action>) {
    self.store = store
    self.viewStore = ViewStore2(store: self.store)
  }

  var body: some View {
    HStack {
      Text(viewStore.store.state.count.description)
      Button("Increment") {
        store.send(.incr)
      }
    }
    .task {
      viewStore.store.send(.onTask)
    }
  }
}

@Reducer
struct ListFeature {
  struct State {
    var rows = IdentifiedArray(
      uncheckedUniqueElements: (1...10_000).map {
        Counter.State(_count: $0)
      }
    )
  }
  enum Action {
    case rows(IdentifiedActionOf<Counter>)
    case incrementFirst
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementFirst:
        state.rows[0].count += 1
        return .none
      default:
        return .none
      }
    }
      .forEach(\.rows, action: \.rows) {
        Counter()
      }
  }
}

struct ListView: View {
  let store = Store2(initialState: ListFeature.State()) {
    ListFeature()._printChanges()
  }

  var body: some View {
    Form {
      ForEachStore2(
        store: store
          .scope(state: \.rows, action: \.rows)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
          .scope(state: \.self, action: \.self)
      ) { store in
        CounterView(store: store)
      }
    }
    .toolbar {
      ToolbarItem {
        Button("Add to first") {
          store.send(.incrementFirst)
        }
      }
    }
  }
}

import OrderedCollections

public struct ForEachStore2<EachState: Identifiable, EachAction, EachContent: View>: View
where EachState.ID: Sendable
{
  let content:  (_ store: Store2<EachState, EachAction>) -> EachContent
  let store: Store2<IdentifiedArray<EachState.ID, EachState>, IdentifiedAction<EachState.ID, EachAction>>
  @ObservedObject var viewStore: ViewStore2<OrderedSet<EachState.ID>, IdentifiedAction<EachState.ID, EachAction>>

  init(
    store: Store2<IdentifiedArray<EachState.ID, EachState>, IdentifiedAction<EachState.ID, EachAction>>,
    @ViewBuilder content: @escaping (_ store: Store2<EachState, EachAction>) -> EachContent
  )
  {
    self.store = store
    self.viewStore = ViewStore2(store: store.scope(state: \.ids, action: \.self))
    self.content = content
  }

  public var body: some View {
    ForEach(viewStore.store.state, id: \.self) { id in
      content(
        store.scope(
          state: \.[id: id]!,
          action: \.[id: id]
        )
      )
    }
  }
}
