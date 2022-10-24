import OrderedCollections
import SwiftUI

// TODO: Other names? `NavigationPathState`? `NavigationStatePath`? `PathState`
// TODO: Should `NavigationState` flatten to just work on `Identifiable` elements?
// TODO: `Sendable where Element: Sendable`
// TODO: Get a better handle on how explicit `ID`s are handled for various navigation scenarios.
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

    @usableFromInline
    init(id: ID? = nil, element: Element) {
      // Reaching out to DependencyValues._current breaks the isolation of the test store
      @Dependency(\.navigationID) var navigationID;
      self.id = id ?? navigationID.next()
      self.element = element
    }
  }

  // TODO: should this be an array of reference boxed values?
  // TODO: should this be publicly exposed?
  @usableFromInline
  var destinations: OrderedDictionary<ID, Element> = [:]

  @inlinable
  @inline(__always)
  public var ids: OrderedSet<ID> {
    self.destinations.keys
  }

  @inlinable
  @inline(__always)
  public var elements: [Element] {
    self.destinations.values.elements
  }

  @inlinable
  public init() {}

  @inlinable
  public subscript(id id: ID) -> Element? {
    _read { yield self.destinations[id] }
    _modify { yield &self.destinations[id] }
  }

  @discardableResult
  @inlinable
  public mutating func append(_ element: Element) -> ID {
    let destination = Destination(element: element)
    self.destinations[destination.id] = destination.element
    return destination.id
  }

  @inlinable
  @inline(__always)
  public var startIndex: Int {
    self.destinations.elements.startIndex
  }

  @inlinable
  @inline(__always)
  public var endIndex: Int {
    self.destinations.elements.endIndex
  }

  @inlinable
  @inline(__always)
  public func index(after i: Int) -> Int {
    self.destinations.elements.index(after: i)
  }

  @inlinable
  public subscript(position: Int) -> Destination {
    _read {
      yield Destination(
        id: self.destinations.keys[position], element: self.destinations.values[position]
      )
    }
    _modify {
      var destination = Destination(
        id: self.destinations.keys[position], element: self.destinations.values[position]
      )
      yield &destination
      self.destinations[destination.id] = destination.element
    }
    set {
      let (_, index) = self.destinations.updateValue(
        newValue.element, forKey: newValue.id, insertingAt: position
      )
      // TODO: Runtime warning finesse?
      assert(index == position)
    }
  }

  @inlinable
  public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
  where C.Element == Destination {
    self.destinations.removeSubrange(subrange)
    for destination in newElements.reversed() {
      self.destinations.updateValue(
        destination.element, forKey: destination.id, insertingAt: subrange.startIndex
      )
    }
  }

  @inlinable
  public mutating func swapAt(_ i: Int, _ j: Int) {
    self.destinations.swapAt(i, j)
  }

  public struct Path:
    MutableCollection,
    RandomAccessCollection,
    RangeReplaceableCollection
  {
    @usableFromInline
    var state: NavigationState

    @inlinable
    init(state: NavigationState) {
      self.state = state
    }

    @inlinable
    public init() { self.state = NavigationState() }

    @inlinable
    @inline(__always)
    public var startIndex: Int {
      self.state.startIndex
    }

    @inlinable
    @inline(__always)
    public var endIndex: Int {
      self.state.endIndex
    }

    @inlinable
    @inline(__always)
    public func index(after i: Int) -> Int {
      self.state.index(after: i)
    }

    @inlinable
    public subscript(position: Int) -> Element {
      _read { yield self.state[position].element }
      _modify { yield &self.state[position].element }
      set { self.state[position].element = newValue }
    }

    @inlinable
    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
    where C.Element == Element {
      self.state.replaceSubrange(subrange, with: newElements.map { Destination(element: $0) })
    }

    @inlinable
    public mutating func swapAt(_ i: Int, _ j: Int) {
      self.state.swapAt(i, j)
    }
  }

  @inlinable
  public init(wrappedValue: Path = []) {
    self = wrappedValue.state
  }

  @inlinable
  public var wrappedValue: Path {
    _read { yield Path(state: self) }
    _modify {
      var path = Path(state: self)
      yield &path
      self = path.state
    }
  }

  @inlinable
  public var projectedValue: Self {
    _read { yield self }
    _modify { yield &self }
  }
}

public typealias NavigationStateOf<R: ReducerProtocol> = NavigationState<R.State>
where R.State: Hashable

extension NavigationState: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Element...) {
    self.init(wrappedValue: Path(elements))
  }
}

extension NavigationState: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (ID, Element)...) {
    self.destinations = .init(uniqueKeysWithValues: elements)
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
      self.id = DependencyValues._current.navigationID.next()
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

extension NavigationState: Decodable where Element: Decodable {
  public init(from decoder: Decoder) throws {
    try self.init([Destination](from: decoder))
  }
}
extension NavigationState: Encodable where Element: Encodable {
  public func encode(to encoder: Encoder) throws {
    try Array(self).encode(to: encoder)
  }
}

extension NavigationState.Path: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }
}

public enum NavigationAction<State: Hashable, Action> {
  // TODO: Does it make sense to fold `dismiss` into `element`?
  case dismiss(id: NavigationState.ID)
  case element(id: NavigationState.ID, Action)
  case setPath(NavigationState<State>)
}

public typealias NavigationActionOf<R: ReducerProtocol> = NavigationAction<R.State, R.Action>
where R.State: Hashable

extension NavigationAction: Equatable where Action: Equatable {}
extension NavigationAction: Hashable where Action: Hashable {}

// TODO: Decodable, Encodable, Sendable, ...?

extension ReducerProtocol {
  @inlinable
  public func navigationDestination<Destinations: ReducerProtocol>(
    _ toNavigationState: WritableKeyPath<State, NavigationStateOf<Destinations>>,
    action toNavigationAction: CasePath<Action, NavigationActionOf<Destinations>>,
    @ReducerBuilderOf<Destinations> destinations: () -> Destinations,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _NavigationDestinationReducer<Self, Destinations> {
    .init(
      base: self,
      toNavigationState: toNavigationState,
      toNavigationAction: toNavigationAction,
      destinations: destinations(),
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _NavigationDestinationReducer<
  Base: ReducerProtocol,
  Destinations: ReducerProtocol
>: ReducerProtocol
where Destinations.State: Hashable {
  @usableFromInline
  let base: Base

  @usableFromInline
  let toNavigationState: WritableKeyPath<Base.State, NavigationStateOf<Destinations>>

  @usableFromInline
  let toNavigationAction: CasePath<Base.Action, NavigationActionOf<Destinations>>

  @usableFromInline
  let destinations: Destinations

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @usableFromInline
  enum DismissID {}

  @inlinable
  init(
    base: Base,
    toNavigationState: WritableKeyPath<Base.State, NavigationStateOf<Destinations>>,
    toNavigationAction: CasePath<Base.Action, NavigationActionOf<Destinations>>,
    destinations: Destinations,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    self.base = base
    self.toNavigationState = toNavigationState
    self.toNavigationAction = toNavigationAction
    self.destinations = destinations
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  @inlinable
  public func reduce(into state: inout Base.State, action: Base.Action) -> EffectTask<Base.Action> {
    var effects: [EffectTask<Base.Action>] = []

    let previousPath = state[keyPath: self.toNavigationState]

    switch self.toNavigationAction.extract(from: action) {
    case let .dismiss(id):
      guard let index = state[keyPath: self.toNavigationState].destinations.index(forKey: id)
      else {
        runtimeWarn(
          """
          A "navigationDestination" at "\(self.fileID):\(self.line)" requested dismissal of a \
          missing element.

            ID:
              \(id)

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • TODO
          """,
          file: self.file,
          line: self.line
        )
        break
      }

      // TODO:
      //   Or should dismiss simply remove the element?
      //   Or should dismiss warn/no-op if the element isn't _the_ presented element?
      //     (Closest to SwiftUI behavior, which doesn't warn but ignores dismissal)
      // TODO: Should this delegate to `setPath` instead for parents to listen to?
      //   Or should parents have to listen to both of these actions or just have the option?
      state[keyPath: self.toNavigationState].removeSubrange(index...)
      break

    case let .element(id, localAction):
      guard let index = state[keyPath: self.toNavigationState].firstIndex(where: { $0.id == id })
      else {
        runtimeWarn(
          """
          A "navigationDestination" at "\(self.fileID):\(self.line)" received an action for a \
          missing element.

            Action:
              \(debugCaseOutput(action))

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • TODO
          """,
          file: self.file,
          line: self.line
        )
        break
      }
      effects.append(
        self.destinations
          // TODO: 👇
          // .dependency(\.popToRoot, ...)
          // .dependency(\.navigation.dismiss, ...)
          // .dependency(\.navigation.id, ...)
          // .dependency(\.navigation.popToRoot, ...)
          // .dependency(\.navigation.popLast(...), ....)
          // .dependency(\.navigation.currentStack(...), ...)
          .dependency(\.dismiss, DismissEffect { Task.cancel(id: DismissID.self) })
          .dependency(\.navigationID.current, id)
          .reduce(
            into: &state[keyPath: self.toNavigationState][index].element,
            action: localAction
          )
          .map { self.toNavigationAction.embed(.element(id: id, $0)) }
          .cancellable(id: id)
      )

    // TODO: Track insertions, removals in action for parent to listen to?
    // .setPath(PathUpdate { newPath: Path, presented: [Element], dismissed: [Element] })
    case let .setPath(newPath):
      state[keyPath: self.toNavigationState] = newPath

    case .none:
      break
    }

    effects.append(self.base.reduce(into: &state, action: action))

    let newPath = state[keyPath: self.toNavigationState]
    let presentedIDs = newPath.ids.subtracting(previousPath.ids)
    let dismissedIDs = previousPath.ids.subtracting(newPath.ids)

    for id in presentedIDs {
      effects.append(
        .run { send in
          do {
            try await DependencyValues.withValue(\.navigationID.current, id) {
              try await withTaskCancellation(id: DismissID.self) {
                try await Task.never()
              }
            }
          } catch is CancellationError {
            await send(self.toNavigationAction.embed(.dismiss(id: id)))
          }
        }
          .cancellable(id: id)
      )
    }
    for id in dismissedIDs {
      effects.append(.cancel(id: id))
    }

    return .merge(effects)
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

    // TODO: memcmp ids and then fallback to comparing enum tags?
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
