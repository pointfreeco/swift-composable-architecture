import ComposableArchitecture
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    WindowGroup {
//      AppView(
//        store: Store(initialState: Todos.State()) {
//          Todos()._printChanges()
//        }
//      )
//      ParentView()
      CounterView(
        store: Store2(initialState: Counter.State()) {
          Counter()
        }
      )
//      NavigationStack {
//        ListView()
//      }
    }
  }
}



import Combine



final class Store2<State, Action> {
  var root: Any!
  var _state: AnyKeyPath
  var send: (Action) -> Void
  let didSet: PassthroughSubject<Void, Never>

  var state: State {
    self.root[keyPath: self._state] as! State
  }

  subscript<Member>(dynamicMember keyPath: KeyPath<State, Member>) -> Member {
    self.state[keyPath: self._state] as! Member
  }

  convenience init(
    initialState: State,
    @ReducerBuilder<State, Action> reducer: () -> some Reducer<State, Action>
  ) {
    let reducer = reducer()
    let didSet = PassthroughSubject<Void, Never>()
    var state = initialState {
      didSet {
        didSet.send()
      }
    }
    self.init(
      didSet: didSet,
      state: \Store2<State, Action>.state,
      send: { action in
        _ = reducer.reduce(into: &state, action: action)
      }
    )
    self.root = self
  }

  private init(
    didSet: PassthroughSubject<Void, Never>,
    state: AnyKeyPath,
    send: @escaping (Action) -> Void,
    root: Any? = nil
  ) {
    self.didSet = didSet
    self._state = state
    self.send = send
    self.root = root
  }

  func scope<ChildState, ChildAction>(
    state: KeyPath<State, ChildState>,
    action actionCP: CaseKeyPath<Action, ChildAction>
  ) -> Store2<ChildState, ChildAction> {
    return Store2<ChildState, ChildAction>(
      didSet: self.didSet,
      state: self._state.appending(path: state)!,
      send: { action in
        self.send(actionCP(action))
      },
      root: self.root
    )
  }
}

class ViewStore2<State: Equatable, Action>: ObservableObject {
  let store: Store2<State, Action>
  var cancellable: AnyCancellable?

  init(store: Store2<State, Action>) {
    self.store = store

    var previous = store.state
    self.cancellable = self.store.didSet
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
