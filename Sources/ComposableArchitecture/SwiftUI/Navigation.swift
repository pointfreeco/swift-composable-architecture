import SwiftUI

// TODO: Other names? `NavigationPathState`? `NavigationStatePath`?
// TODO: Should `NavigationState` flatten to just work on `Identifiable` elements?
// TODO: `Sendable where Element: Sendable`
@propertyWrapper
public struct NavigationState<Element: Hashable>:
  MutableCollection,
  RandomAccessCollection,
  RangeReplaceableCollection
{
  public typealias ID = AnyHashable

  public struct Destination: Identifiable {
    public let id: ID
    public var element: Element

    public init(id: ID? = nil, element: Element) {
      self.id = id ?? DependencyValues.current.navigationID.next()
      self.element = element
    }
  }

  // TODO: should this be an array of reference boxed values?
  var destinations: [Destination] = []

  public init() {}

  public subscript(id id: ID) -> Element? {
    _read {
      guard let index = self.destinations.firstIndex(where: { $0.id == id })
      else {
        yield nil
        return
      }
      yield self.destinations[index].element
    }
    _modify {
      guard let index = self.destinations.firstIndex(where: { $0.id == id })
      else {
        var element: Element? = nil
        yield &element
        return
      }
      var element: Element! = self.destinations[index].element
      yield &element
      self.destinations[index].element = element
    }
    set {
      switch (self.destinations.firstIndex(where: { $0.id == id }), newValue) {
      case let (.some(index), .some(newValue)):
        self.destinations[index].element = newValue

      case let (.some(index), .none):
        self.destinations.remove(at: index)

      case let (.none, .some(newValue)):
        self.append(newValue)

      case (.none, .none):
        break
      }
    }
  }

  @discardableResult
  public mutating func append(_ element: Element) -> ID {
    let destination = Destination(element: element)
    self.destinations.append(destination)
    return destination.id
  }

  public var startIndex: Int {
    self.destinations.startIndex
  }

  public var endIndex: Int {
    self.destinations.endIndex
  }

  public func index(after i: Int) -> Int {
    self.destinations.index(after: i)
  }

  public subscript(position: Int) -> Destination {
    _read { yield self.destinations[position] }
    _modify { yield &self.destinations[position] }
    set { self.destinations[position] = newValue }
  }

  public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
  where C.Element == Destination {
    self.destinations.replaceSubrange(subrange, with: newElements)
  }

  public struct Path:
    MutableCollection,
    RandomAccessCollection,
    RangeReplaceableCollection
  {
    var state: NavigationState

    init(state: NavigationState) {
      self.state = state
    }

    public init() { self.state = NavigationState() }

    public var startIndex: Int {
      self.state.startIndex
    }

    public var endIndex: Int {
      self.state.endIndex
    }

    public func index(after i: Int) -> Int {
      self.state.index(after: i)
    }

    public subscript(position: Int) -> Element {
      _read { yield self.state[position].element }
      _modify { yield &self.state[position].element }
      set { self.state[position].element = newValue }
    }

    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
    where C.Element == Element {
      self.state.replaceSubrange(subrange, with: newElements.map { Destination(element: $0) })
    }

    public mutating func swapAt(_ i: Int, _ j: Int) {
      self.state.swapAt(i, j)
    }
  }

  public init(wrappedValue: Path = []) {
    self = wrappedValue.state
  }

  public var wrappedValue: Path {
    _read { yield Path(state: self) }
    _modify {
      var path = Path(state: self)
      yield &path
      self = path.state
    }
  }

  public var projectedValue: Self {
    _read { yield self }
    _modify { yield &self }
  }
}

public typealias NavigationStateOf<R: ReducerProtocol> = NavigationState<R.State>
where R.State: Hashable

extension NavigationState: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (ID, Element)...) {
    self.destinations = .init(elements.map(Destination.init(id:element:)))
  }
}

extension NavigationState.Destination {
  private enum CodingKeys: CodingKey {
    case idTypeName
    case idString
    case element
  }
}

extension NavigationState.Destination: Decodable where Element: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let idTypeName = try? container.decode(String.self, forKey: .idTypeName),
      let idType = _typeByName(idTypeName),
      let idString = try? container.decode(String.self, forKey: .idString),
      let id = try? _decode(idType, from: Data(idString.utf8)) as? AnyHashable
    {
      self.id = id
    } else {
      self.id = UUID()
    }
    self.element = try container.decode(Element.self, forKey: .element)
  }
}

extension NavigationState.Destination: Encodable where Element: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let id = self.id.base
    if let idData = try? _encode(self.id.base) {
      try container.encode(_typeName(type(of: id)), forKey: .idTypeName)
      try container.encode(String(decoding: idData, as: UTF8.self), forKey: .idString)
    } else if let idData = try? _encode(UUID()) {
      try container.encode(_typeName(UUID.self), forKey: .idTypeName)
      try container.encode(String(decoding: idData, as: UTF8.self), forKey: .idString)
    }
    try container.encode(element, forKey: .element)
  }
}

extension NavigationState.Destination: Equatable where Element: Equatable {}
extension NavigationState.Destination: Hashable where Element: Hashable {}

extension NavigationState: Equatable where Element: Equatable {}
extension NavigationState: Hashable where Element: Hashable {}

extension NavigationState: Decodable where Element: Decodable {}
extension NavigationState: Encodable where Element: Encodable {}

extension NavigationState.Path: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }
}

public enum NavigationAction<State: Hashable, Action> {
  case element(id: NavigationState.ID, Action)
  case setPath(NavigationState<State>)
}

public typealias NavigationActionOf<R: ReducerProtocol> = NavigationAction<R.State, R.Action>
where R.State: Hashable

extension NavigationAction: Equatable where Action: Equatable {}
extension NavigationAction: Hashable where Action: Hashable {}

extension ReducerProtocol {
  public func navigationDestination<Destinations: ReducerProtocol>(
    state toNavigationState: WritableKeyPath<State, NavigationStateOf<Destinations>>,
    action toNavigationAction: CasePath<Action, NavigationActionOf<Destinations>>,
    @ReducerBuilderOf<Destinations> destinations: () -> Destinations
  ) -> NavigationDestinationReducer<Self, Destinations> {
    .init(
      upstream: self,
      toNavigationState: toNavigationState,
      toNavigationAction: toNavigationAction,
      destinations: destinations()
    )
  }
}

public struct NavigationDestinationReducer<
  Upstream: ReducerProtocol,
  Destinations: ReducerProtocol
>: ReducerProtocol
where Destinations.State: Hashable {
  let upstream: Upstream
  let toNavigationState: WritableKeyPath<Upstream.State, NavigationStateOf<Destinations>>
  let toNavigationAction: CasePath<Upstream.Action, NavigationActionOf<Destinations>>
  let destinations: Destinations

  public var body: some ReducerProtocol<Upstream.State, Upstream.Action> {
    Reduce { globalState, globalAction in
      guard let navigationAction = toNavigationAction.extract(from: globalAction)
      else { return .none }

      switch navigationAction {
      case let .element(id, localAction):
        guard let index = globalState[keyPath: toNavigationState].firstIndex(where: { $0.id == id })
        else {
          // TODO: runtime warning
          return .none
        }
        return self.destinations
          .dependency(\.navigationID.current, id)
          .reduce(
            into: &globalState[keyPath: toNavigationState][index].element,
            action: localAction
          )
          .map { toNavigationAction.embed(.element(id: id, $0)) }
          .cancellable(id: id)

      case let .setPath(path):
        var removedIds: Set<AnyHashable> = []
        for destination in globalState[keyPath: toNavigationState].destinations {
          removedIds.insert(destination.id)
        }
        for destination in path {
          removedIds.remove(destination.id)
        }
        globalState[keyPath: toNavigationState] = path
        return .merge(removedIds.map { .cancel(id: $0) })
      }
    }

    self.upstream

    // TODO: Run `upstream` before dismissal? See presentation for this behavior.
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct NavigationStackStore<Element: Hashable, Content: View>: View {
  let store: Store<NavigationState<Element>, NavigationState<Element>>
  let content: Content

  public init<Action>(
    _ store: Store<NavigationState<Element>, NavigationAction<Element, Action>>,
    @ViewBuilder content: () -> Content
  ) {
    self.store = store.scope(state: { $0 }, action: { .setPath($0) })
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
    lhs: NavigationState<Element>,
    rhs: NavigationState<Element>
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

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension View {
  @ViewBuilder
  public func navigationDestination<State: Hashable, Action, Content: View>(
    store: Store<NavigationState<State>, NavigationAction<State, Action>>,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.navigationDestination(for: NavigationState<State>.Destination.self) { state in
      IfLetStore(
        store.scope(
          state: returningLastNonNilValue { $0[id: state.id] ?? state.element },
          action: { .element(id: state.id, $0) }
        ),
        then: destination
      )
    }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationLink where Destination == Never {
  public init<D: Hashable>(state: D?, label: () -> Label) {
    self.init(
      value: state.map { NavigationState.Destination(id: UUID(), element: $0) }, label: label)
  }

  public init<D: Hashable>(_ titleKey: LocalizedStringKey, state: D?) where Label == Text {
    self.init(titleKey, value: state.map { NavigationState.Destination(id: UUID(), element: $0) })
  }

  public init<S: StringProtocol, D: Hashable>(_ title: S, state: D?) where Label == Text {
    self.init(title, value: state.map { NavigationState.Destination(id: UUID(), element: $0) })
  }
}
