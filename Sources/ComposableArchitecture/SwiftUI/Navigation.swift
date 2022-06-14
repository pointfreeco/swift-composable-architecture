import SwiftUI

struct NavigationState<Element>: MutableCollection, RandomAccessCollection, RangeReplaceableCollection {
  typealias ID = AnyHashable

  struct Route: Identifiable {
    var id: AnyHashable
    var element: Element

    init(id: AnyHashable, element: Element) {
      self.id = id
      self.element = element
    }
  }

  // TODO: replace IdentifiedArray with OrderedDictionary?
  var path = IdentifiedArrayOf<Route>()

  var startIndex: Int {
    self.path.startIndex
  }
  var endIndex: Int {
    self.path.endIndex
  }
  func index(after i: Int) -> Int {
    self.path.index(after: i)
  }
  subscript(position: Int) -> Route {
    _read { yield self.path[position] }
    _modify { yield &self.path[position] }
  }
  mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
  where C: Collection, Route == C.Element {
    self.path.replaceSubrange(
      subrange,
      with: newElements
    )
  }
  mutating func append(_ newElement: Element) where Element: Identifiable {
    self.append(.init(id: newElement.id, element: newElement))
  }

  subscript(id id: ID) -> Element? {
    get {
      self.path[id: id]?.element
    }
    set {
      if let newValue = newValue {
        self.path[id: id] = .init(id: id, element: newValue)
      }
    }
  }
}

extension NavigationState: ExpressibleByDictionaryLiteral {
  init(dictionaryLiteral elements: (ID, Element)...) {
    self.path = .init(uniqueElements: elements.map(Route.init(id:element:)))
  }
}

extension NavigationState.Route: Equatable where Element: Equatable {}
extension NavigationState.Route: Hashable where Element: Hashable {}
extension NavigationState: Equatable where Element: Equatable {}
extension NavigationState: Hashable where Element: Hashable {}

extension NavigationState: ExpressibleByArrayLiteral {
  init(arrayLiteral elements: Route...) {
    self.init(path: .init(uniqueElements: elements))
  }
}

enum NavigationAction<State, Action> {
  case element(id: NavigationState.ID, Action)
  case setPath(NavigationState<State>)
}

protocol NavigableAction {
  associatedtype State
  associatedtype Action
  static func navigation(_: NavigationAction<State, Action>) -> Self
}

protocol NavigableState {
  associatedtype State: Hashable
  var path: NavigationState<State> { get set }
}

@available(iOS 16.0, macOS 13.0, *)
struct NavigationStackStore<State: NavigableState, Action: NavigableAction, Content: View>: View
where State.State == Action.State
{
  let store: Store<NavigationState<State.State>, NavigationState<State.State>>
  let content: Content
  init(
    store: Store<State, Action>,
    @ViewBuilder content: () -> Content
  ) {
    self.store = store.scope(state: \.path, action: { Action.navigation(.setPath($0)) })
    self.content = content()
  }

  var body: some View {
    WithViewStore(self.store, removeDuplicates: Self.isEqual) { viewStore in
      NavigationStack(
        // TODO: animation binding
        path: .init(get: { self.store.state.value }, set: { self.store.send($0) })
      ) {
        self.content
      }
    }
  }

  private static func isEqual(
    lhs: NavigationState<State.State>,
    rhs: NavigationState<State.State>
  ) -> Bool {
    guard lhs.count == rhs.count
    else { return false }
    for (lhs, rhs) in zip(lhs, rhs) {
      guard lhs.id == rhs.id && enumTag(lhs.element) == enumTag(rhs.element)
      else { return false }
    }
    return true
  }
}

extension Reducer where State: NavigableState, Action: NavigableAction {
  func navigationDestination(
    _ reducers: Reducer<Action.State, Action.Action, Environment>...
  ) -> Self
  where State.State == Action.State
  {
    let reducer = Reducer<Action.State, Action.Action, Environment>.combine(reducers)
    return .combine(
      .init { globalState, globalAction, globalEnvironment in
        guard let navigationAction = CasePath(Action.navigation).extract(from: globalAction)
        else { return .none }

        switch navigationAction {
        case let .element(id, localAction):
          guard let index = globalState.path.firstIndex(where: { $0.id == id })
          else { return .none }
          return reducer
            .run(
              &globalState.path[index].element,
              localAction,
              globalEnvironment
            )
            .map { Action.navigation(.element(id: id, $0)) }
            .cancellable(id: id)

        case let .setPath(path):
          let removedIds = globalState.path.path.ids.compactMap {
            !path.path.ids.contains($0) ? $0 : nil
          }
          globalState.path = path
          return .cancel(ids: removedIds)
        }
      },
      self
    )
  }
}


private class StoreObservableObject<State, Action>: ObservableObject {
  let id: NavigationState.ID
  let wrappedValue: Store<State, Action>

  init(id: NavigationState.ID, store: Store<State, Action>) {
    self.id = id
    self.wrappedValue = store
  }
}

struct DestinationStore<State, Action, DestinationState, DestinationAction, Destination: View>: View {
  @EnvironmentObject private var store: StoreObservableObject<NavigationState<State>, NavigationAction<State, Action>>

  let state: (State) -> DestinationState?
  let action: (DestinationAction) -> Action
  let content: (Store<DestinationState, DestinationAction>) -> Destination

  var body: some View {
    IfLetStore(
      self.store.wrappedValue.scope(
        state: { _state in (_state.path[id: store.id]?.element).flatMap(state) },
        action: { _action in .element(id: store.id, action(_action)) }
      )
    ) {
      content($0)
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
extension View {
  @ViewBuilder
  func navigationDestination<State: NavigableState, Action: NavigableAction, Content>(
    store: Store<State, Action>,
    @ViewBuilder destination: @escaping () -> Content
  )
  -> some View
  where
    Content: View,
    State.State == Action.State
  {
    self.navigationDestination(for: NavigationState<State.State>.Route.self) { route in
      if let innerRoute = store.state.value.path.last(where: { $0 == route }) {
        destination()
          .environmentObject(
            StoreObservableObject(
              id: innerRoute.id,
              store: store.scope(state: \.path, action: Action.navigation)
            )
          )
      } else {
        // TODO: runtime warning view
      }
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
extension NavigationLink where Destination == Never {
  init<Route: Hashable>(route: Route, label: () -> Label) {
    self.init(value: NavigationState.Route.init(id: UUID(), element: route), label: label)
  }
}
