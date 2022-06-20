import SwiftUI

// TODO: other names? NavigationPathState? NavigationStatePath?
// TODO: should NavigationState flatten to just work on Identifiable elements?
public struct NavigationState<Element>:
  MutableCollection,
  RandomAccessCollection,
  RangeReplaceableCollection
{
  public typealias ID = AnyHashable

  public struct Destination: Identifiable {
    public var id: ID
    public var element: Element

    public init(id: ID, element: Element) {
      self.id = id
      self.element = element
    }
  }

  public init() {}

  var path = IdentifiedArrayOf<Destination>()

  public var startIndex: Int {
    self.path.startIndex
  }

  public var endIndex: Int {
    self.path.endIndex
  }

  public func index(after i: Int) -> Int {
    self.path.index(after: i)
  }

  public subscript(position: Int) -> Destination {
    _read { yield self.path[position] }
    _modify {
      var element = self.path[position]
      yield &element
      self.path.update(element, at: position)
    }
    set {
      self.path.update(newValue, at: position)
    }
  }

  public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
  where C: Collection, Destination == C.Element {
    self.path.removeSubrange(subrange)
    for element in newElements.reversed() {
      self.path.insert(element, at: subrange.startIndex)
    }
  }

  public subscript(id id: ID) -> Element? {
    _read { yield self.path[id: id]?.element }
    _modify {
      var element = self.path[id: id]?.element
      yield &element
      self.path[id: id] = element.map { .init(id: id, element: $0) }
    }
    set {
      self.path[id: id] = newValue.map { .init(id: id, element: $0) }
    }
  }
}

extension NavigationState: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (ID, Element)...) {
    self.path = .init(uniqueElements: elements.map(Destination.init(id:element:)))
  }
}

extension NavigationState.Destination: Equatable where Element: Equatable {}
extension NavigationState.Destination: Hashable where Element: Hashable {}
extension NavigationState: Equatable where Element: Equatable {}
extension NavigationState: Hashable where Element: Hashable {}

extension NavigationState: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Destination...) {
    self.init(elements)
  }
}

public enum NavigationAction<State, Action> {
  case element(id: NavigationState.ID, Action)
  case setPath(NavigationState<State>)
}

extension NavigationAction: Equatable where State: Equatable, Action: Equatable {}
extension NavigationAction: Hashable where State: Hashable, Action: Hashable {}

public protocol NavigableAction {
  associatedtype DestinationState
  associatedtype DestinationAction
  static func navigation(_: NavigationAction<DestinationState, DestinationAction>) -> Self
}

public protocol NavigableState {
  associatedtype DestinationState: Hashable
  // TODO: other names? stack?
  var path: NavigationState<DestinationState> { get set }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct NavigationStackStore<State: NavigableState, Action: NavigableAction, Content: View>: View
where State.DestinationState == Action.DestinationState
{
  let store: Store<NavigationState<State.DestinationState>, NavigationState<State.DestinationState>>
  let content: Content

  public init(
    store: Store<State, Action>,
    @ViewBuilder content: () -> Content
  ) {
    self.store = store.scope(state: { $0.path }, action: { .navigation(.setPath($0)) })
    self.content = content()
  }

  public var body: some View {
    WithViewStore(self.store, removeDuplicates: Self.isEqual) { _ in
      NavigationStack(path: ViewStore(self.store).binding(send: { $0 })) {
        self.content
      }
    }
  }

  private static func isEqual(
    lhs: NavigationState<State.DestinationState>,
    rhs: NavigationState<State.DestinationState>
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

public struct NavigationDestinationReducer<
  Upstream: ReducerProtocol,
  Destinations: ReducerProtocol
>: ReducerProtocol
where
  Upstream.State: NavigableState,
  Upstream.Action: NavigableAction,
  Upstream.State.DestinationState == Upstream.Action.DestinationState,
  Destinations.State == Upstream.Action.DestinationState,
  Destinations.Action == Upstream.Action.DestinationAction
{
  let upstream: Upstream
  let destinations: Destinations

  public var body: some ReducerProtocol<Upstream.State, Upstream.Action> {
    Reduce { globalState, globalAction in
      guard let navigationAction = CasePath(Action.navigation).extract(from: globalAction)
      else { return .none }

      switch navigationAction {
      case let .element(id, localAction):
        guard let index = globalState.path.firstIndex(where: { $0.id == id })
        else {
          // TODO: runtime warning
          return .none
        }
        return self.destinations
          .dependency(\.navigationID.current, id)
          .reduce(
            into: &globalState.path[index].element,
            action: localAction
          )
          .map { .navigation(.element(id: id, $0)) }
          .cancellable(id: id)

      case let .setPath(path):
        let removedIds = globalState.path.path.ids.compactMap {
          !path.path.ids.contains($0) ? $0 : nil
        }
        globalState.path = path
        return .cancel(ids: removedIds)
      }
    }

    self.upstream
  }
}

extension ReducerProtocol where State: NavigableState, Action: NavigableAction {
  public func navigationDestination<Destinations: ReducerProtocol>(
    @ReducerBuilder<Destinations.State, Destinations.Action> destinations: () -> Destinations
  ) -> NavigationDestinationReducer<Self, Destinations> {
    .init(upstream: self, destinations: destinations())
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

public struct DestinationStore<
  State,
  Action,
  DestinationState,
  DestinationAction,
  Destination: View
>: View {
  @EnvironmentObject private var store: StoreObservableObject<
    NavigationState<State>,
    NavigationAction<State, Action>
  >

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
        state: cachedLastSome { _state in (_state.path[id: store.id]?.element).flatMap(state) },
        action: { _action in .element(id: store.id, action(_action)) }
      )
    ) {
      content($0)
    }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension View {
  @ViewBuilder
  public func navigationDestination<State: NavigableState, Action: NavigableAction, Content>(
    store: Store<State, Action>,
    @ViewBuilder destination: @escaping () -> Content
  )
  -> some View
  where
    Content: View,
    State.DestinationState == Action.DestinationState
  {
    self.navigationDestination(for: NavigationState<State.DestinationState>.Destination.self) { route in
      if let destinationState = store.state.value.path.last(where: { $0 == route }) {
        destination()
          .environmentObject(
            StoreObservableObject(
              id: destinationState.id,
              store: store.scope(state: { $0.path }, action: Action.navigation)
            )
          )
      } else {
        // TODO: runtime warning view
      }
    }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationLink where Destination == Never {
  public init<D: Hashable>(state: D?, label: () -> Label) {
    self.init(value: state.map { NavigationState.Destination(id: UUID(), element: $0) }, label: label)
  }

  public init<D: Hashable>(_ titleKey: LocalizedStringKey, state: D?) where Label == Text {
    self.init(titleKey, value: state.map { NavigationState.Destination(id: UUID(), element: $0) })
  }

  public init<S: StringProtocol, D: Hashable>(_ title: S, state: D?) where Label == Text {
    self.init(title, value: state.map { NavigationState.Destination(id: UUID(), element: $0) })
  }
}

private func cachedLastSome<A, B>(_ f: @escaping (A) -> B?) -> (A) -> B? {
  var lastWrapped: B?
  return { wrapped in
    lastWrapped = f(wrapped) ?? lastWrapped
    return lastWrapped
  }
}

// TODO: should we ship these?
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
