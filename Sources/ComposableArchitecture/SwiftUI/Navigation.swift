import SwiftUI

// TODO: other names? NavigationPathState? NavigationStatePath?
// TODO: should NavigationState flatten to just work on Identifiable elements?
public struct NavigationState<Element>: MutableCollection, RandomAccessCollection, RangeReplaceableCollection {
  public typealias ID = AnyHashable

  public struct Route: Identifiable {
    public var id: AnyHashable
    public var element: Element

    public init(id: ID, element: Element) {
      self.id = id
      self.element = element
    }
  }

  public init() {
  }
  public init(path: IdentifiedArrayOf<Route>) {
    self.path = path
  }

  // TODO: replace IdentifiedArray with OrderedDictionary?
  var path = IdentifiedArrayOf<Route>()

  public var startIndex: Int {
    self.path.startIndex
  }
  public var endIndex: Int {
    self.path.endIndex
  }
  public func index(after i: Int) -> Int {
    self.path.index(after: i)
  }
  public subscript(position: Int) -> Route {
    _read { yield self.path[position] }
    _modify { yield &self.path[position] }
  }
  public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
  where C: Collection, Route == C.Element {
    self.path.replaceSubrange(
      subrange,
      with: newElements
    )
  }

  public subscript(id id: ID) -> Element? {
    get {
      self.path[id: id]?.element
    }
    set {
      if let newValue = newValue {
        self.path[id: id] = .init(id: id, element: newValue)
      }
    }
  }

  public func dropLast(_ k: Int = 1) -> Self {
    .init(path: .init(uniqueElements: self.path.dropLast(k)))
  }
}

extension NavigationState: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (ID, Element)...) {
    self.path = .init(uniqueElements: elements.map(Route.init(id:element:)))
  }
}

extension NavigationState.Route: Equatable where Element: Equatable {}
extension NavigationState.Route: Hashable where Element: Hashable {}
// TODO: open up AnyHashable to detect codability?
//extension NavigationState.Route: Encodable where Element: Encodable {}
//extension NavigationState.Route: Decodable where Element: Decodable {}
extension NavigationState: Equatable where Element: Equatable {}
extension NavigationState: Hashable where Element: Hashable {}
//extension NavigationState: Decodable where Element: Decodable {}
//extension NavigationState: Encodable where Element: Encodable {}

extension NavigationState: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Route...) {
    self.init(path: .init(uniqueElements: elements))
  }
}

public enum NavigationAction<State, Action> {
  case element(id: NavigationState.ID, Action)
  case setPath(NavigationState<State>)
}

extension NavigationAction: Equatable where State: Equatable, Action: Equatable {}
extension NavigationAction: Hashable where State: Hashable, Action: Hashable {}

public protocol NavigableAction {
  associatedtype State
  associatedtype Action
  static func navigation(_: NavigationAction<State, Action>) -> Self
}

public protocol NavigableState {
  associatedtype State: Hashable
  // TODO: other names? stack?
  var path: NavigationState<State> { get set }
}

@available(iOS 16.0, macOS 13.0, *)
public struct NavigationStackStore<State: NavigableState, Action: NavigableAction, Content: View>: View
where State.State == Action.State
{
  let store: Store<NavigationState<State.State>, NavigationState<State.State>>
  let content: Content
  public init(
    store: Store<State, Action>,
    @ViewBuilder content: () -> Content
  ) {
    self.store = store.scope(state: \.path, action: { Action.navigation(.setPath($0)) })
    self.content = content()
  }

  public var body: some View {
    WithViewStore(self.store, removeDuplicates: Self.isEqual) { _ in
      NavigationStack(
        path: ViewStore(self.store).binding(send: { $0 })
        // TODO: cool to use ViewStore.binding or should we construct manually?
//        .init(
//          get: { self.store.state.value },
//          set: {
//            self.store.send($0)
//          }
//        )
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
  public func navigationDestination(
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
          else {
            // TODO: runtime warning
            return .none
          }
          return reducer
            // TODO: once we have @Dependency, explore this: .dependency(\.navigationId, id)
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

public struct DestinationStore<State, Action, DestinationState, DestinationAction, Destination: View>: View {
  @EnvironmentObject private var store: StoreObservableObject<NavigationState<State>, NavigationAction<State, Action>>

  let state: (State) -> DestinationState?
  let action: (DestinationAction) -> Action
  let content: (Store<DestinationState, DestinationAction>) -> Destination

  public init(
    state: @escaping (State) -> DestinationState?,
    action: @escaping (DestinationAction) -> Action,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Destination
  ) {
    self.state = state
    self.action = action
    self.content = content
  }

  public var body: some View {
    IfLetStore(
      self.store.wrappedValue.scope(
        state: { _state in (_state.path[id: store.id]?.element).flatMap(state) },
        action: { _action in .element(id: store.id, action(_action)) }
      )
      .scope(state: Optional.cacheLastSome)
    ) {
      content($0)
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
extension View {
  @ViewBuilder
  public func navigationDestination<State: NavigableState, Action: NavigableAction, Content>(
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
  public init<Route: Hashable>(route: Route, label: () -> Label) {
    self.init(value: NavigationState.Route.init(id: UUID(), element: route), label: label)
  }
}

extension Optional {
  fileprivate static var cacheLastSome: (Self) -> Self {
    var lastWrapped: Wrapped?
    return {
      lastWrapped = $0 ?? lastWrapped
      return lastWrapped
    }
  }
}

extension NavigationAction {
  public static var removeAll: Self {
    .setPath([])
  }
}
extension NavigableAction {
  public static var popToRoot: Self {
    .navigation(.setPath([]))
  }
}
