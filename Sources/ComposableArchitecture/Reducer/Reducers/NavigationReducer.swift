import Foundation
import OrderedCollections

// TODO: Better name? `DestinationID`?
public struct ElementID: Hashable, Sendable {
  private let id = UUID()
}

@propertyWrapper
public struct NavigationState<
  State
>: BidirectionalCollection, MutableCollection, RandomAccessCollection, RangeReplaceableCollection {
  var _ids: OrderedSet<ElementID>
  var _elements: [ElementID: State] // TODO: [ElementID: (state: State, isPresented: Bool)]

  public var startIndex: Int { self._ids.startIndex }

  public var endIndex: Int { self._ids.endIndex }

  public func index(after i: Int) -> Int { self._ids.index(after: i) }

  public func index(before i: Int) -> Int { self._ids.index(before: i) }

  public subscript(position: Int) -> State {
    _read { yield self._elements[self._ids[position]]! }
    _modify { yield &self._elements[self._ids[position]]! }
  }

  public init() {
    self._ids = []
    self._elements = [:]
  }

  public init(wrappedValue: Self = []) {
    self = wrappedValue
  }

  public var wrappedValue: Self {
    _read { yield self }
    _modify { yield &self }
  }

  public var projectedValue: Path {
    _read { yield Path(state: self) }
    _modify {
      var path = Path(state: self)
      yield &path
      self = path.state
    }
  }

  public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
  where State == C.Element {
    for id in self._ids[subrange] {
      self._elements[id] = nil
    }
    self._ids.removeSubrange(subrange)
    for element in newElements.reversed() {
      let id = ElementID()
      self._ids.insert(id, at: subrange.startIndex)
      self._elements[id] = element
    }
  }

  public struct Path {
    var state: NavigationState

    public subscript(id: ElementID) -> State {
      _read { yield self.state._elements[id]! }
      _modify { yield &self.state._elements[id]! }
    }

    @discardableResult
    public mutating func remove(id: ElementID) -> State {
      self.state._ids.remove(id)
      return self.state._elements.removeValue(forKey: id)!
    }
  }
}

extension NavigationState: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: State...) {
    self.init(elements)
  }
}

extension NavigationState: Equatable where State: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs._ids.lazy.map { lhs._elements[$0]! }
      == rhs.wrappedValue._ids.lazy.map { rhs._elements[$0]! }
  }
}

extension NavigationState: Hashable where State: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.count)
    for id in self._ids {
      hasher.combine(self._elements[id]!)
    }
  }
}

extension NavigationState: Decodable where State: Decodable {
  public init(from decoder: Decoder) throws {
    try self.init([State](from: decoder))
  }
}

extension NavigationState: Encodable where State: Encodable {
  public func encode(to encoder: Encoder) throws {
    try [State](self).encode(to: encoder)
  }
}

extension NavigationState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: [State](self))
  }
}

public enum NavigationAction<Action> {
  case dismiss(id: ElementID)
  case element(id: ElementID, Action)
  // TODO: Possible to present arbitrary state in a lightweight way?
  // case present(Any) // present<State>(State) ~=
  case pathChanged(ids: [ElementID])
}

extension NavigationAction: Equatable where Action: Equatable {}

extension NavigationAction: Hashable where Action: Hashable {}

extension ReducerProtocol {
  public func navigates<DestinationState, DestinationAction, Destination: ReducerProtocol>(
    _ toNavigationState: WritableKeyPath<State, NavigationState<DestinationState>.Path>,
    action toNavigationAction: CasePath<Action, NavigationAction<DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _NavigationReducer<Self, Destination>
  where Destination.State == DestinationState, Destination.Action == DestinationAction {
    _NavigationReducer(
      base: self,
      toNavigationState: toNavigationState,
      toNavigationAction: toNavigationAction,
      destination: destination(),
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _NavigationReducer<
  Base: ReducerProtocol, Destination: ReducerProtocol
>: ReducerProtocol {
  let base: Base
  let toNavigationState: WritableKeyPath<Base.State, NavigationState<Destination.State>.Path>
  let toNavigationAction: CasePath<Base.Action, NavigationAction<Destination.Action>>
  let destination: Destination
  let file: StaticString
  let fileID: StaticString
  let line: UInt

  @Dependency(\.navigationID) var navigationID

  public func reduce(into state: inout Base.State, action: Base.Action) -> EffectTask<Base.Action> {
    let idsBefore = state[keyPath: self.toNavigationState].state._ids
    let destinationEffects: EffectTask<Base.Action>
    let baseEffects: EffectTask<Base.Action>

    if let navigationAction = self.toNavigationAction.extract(from: action) {
      switch navigationAction {
      case let .dismiss(id):
        destinationEffects = .none
        baseEffects = self.base.reduce(into: &state, action: action)
        state[keyPath: self.toNavigationState].remove(id: id)

      case let .element(elementID, destinationAction):
        let id = self.navigationID(for: elementID)
        destinationEffects = self.destination
          .dependency(\.dismiss, DismissEffect { Task.cancel(id: DismissID(elementID: elementID)) })
          .dependency(\.navigationID, id)
          .reduce(
            into: &state[keyPath: self.toNavigationState].state._elements[elementID]!,
            action: destinationAction
          )
          .map { toNavigationAction.embed(.element(id: elementID, $0)) }
          .cancellable(id: id)
        baseEffects = self.base.reduce(into: &state, action: action)

      case let .pathChanged(ids):
        state[keyPath: self.toNavigationState].state._ids.elements = ids
        destinationEffects = .none
        baseEffects = self.base.reduce(into: &state, action: action)
      }
    } else {
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
    }

    let idsAfter = state[keyPath: self.toNavigationState].state._ids

    let cancelEffects = EffectTask<Base.Action>.merge(
      idsBefore.subtracting(idsAfter).map { .cancel(id: self.navigationID(for: $0)) }
    )
    let presentEffects = EffectTask<Base.Action>.merge(
      idsAfter.subtracting(idsBefore).map { elementID in
        // TODO: `isPresented` logic from `PresentationState`
        let id = self.navigationID(for: elementID)
        return .run { send in
          do {
            try await withDependencies {
              $0.navigationID = id
            } operation: {
              try await withTaskCancellation(id: DismissID(elementID: elementID)) {
                try await Task.never()
              }
            }
          } catch is CancellationError {
            await send(self.toNavigationAction.embed(.dismiss(id: elementID)))
          }
        }
      }
    )

    return .merge(
      destinationEffects,
      baseEffects,
      cancelEffects,
      presentEffects
    )
  }

  private func navigationID(for elementID: ElementID) -> NavigationID {
    self.navigationID
      .appending(path: self.toNavigationState)
      .appending(component: elementID)
  }
}

private struct DismissID: Hashable {
  let elementID: ElementID
}
