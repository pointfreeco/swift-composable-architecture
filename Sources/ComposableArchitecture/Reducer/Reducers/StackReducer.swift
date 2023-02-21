import Foundation
import OrderedCollections

// TODO: Better name? `DestinationID`? `StackElementID`?
public struct ElementID: Hashable, Sendable {
  private let id = UUID()
}

@propertyWrapper
public struct StackState<
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
    var state: StackState

    public subscript(id: ElementID) -> State {
      _read { yield self.state._elements[id]! }
      _modify { yield &self.state._elements[id]! }
    }

    @discardableResult
    public mutating func remove(id: ElementID) -> State {
      self.state._ids.remove(id)
      return self.state._elements.removeValue(forKey: id)!
    }

    public mutating func pop(from id: ElementID) {
      let index = self.state._ids.firstIndex(of: id)! + 1
      for id in self.state._ids[index...] {
        self.state._elements[id] = nil
      }
      self.state._ids.removeSubrange(index...)
    }

    public mutating func pop(to id: ElementID) {
      let index = self.state._ids.firstIndex(of: id)!
      for id in self.state._ids[index...] {
        self.state._elements[id] = nil
      }
      self.state._ids.removeSubrange(index...)
    }
  }
}

extension StackState: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: State...) {
    self.init(elements)
  }
}

extension StackState: Equatable where State: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs._ids.lazy.map { lhs._elements[$0]! }
      == rhs.wrappedValue._ids.lazy.map { rhs._elements[$0]! }
  }
}

extension StackState: Hashable where State: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.count)
    for id in self._ids {
      hasher.combine(self._elements[id]!)
    }
  }
}

extension StackState: Decodable where State: Decodable {
  public init(from decoder: Decoder) throws {
    try self.init([State](from: decoder))
  }
}

extension StackState: Encodable where State: Encodable {
  public func encode(to encoder: Encoder) throws {
    try [State](self).encode(to: encoder)
  }
}

extension StackState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: [State](self))
  }
}

public enum StackAction<Action> {
  // TODO: Possible to present arbitrary state in a lightweight way?
  case element(id: ElementID, Action)
  case pathChanged(PathChange)
  case popFrom(id: ElementID)
  case popTo(id: ElementID)
  case popToRoot // TODO: `removeAll`?
  case present(Any) // present<State>(State) ~=
}

public struct PathChange {
  let ids: [ElementID]
}

extension StackAction: Equatable where Action: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    // TODO: Can't automate with `.present(Any)`. Fix.
    true
  }
}

extension StackAction: Hashable where Action: Hashable {
  public func hash(into hasher: inout Hasher) {
    // TODO: Can't automate with `.present(Any)`. Fix.
  }
}

extension ReducerProtocol {
  public func forEach<DestinationState, DestinationAction, Destination: ReducerProtocol>(
    _ toStackState: WritableKeyPath<State, StackState<DestinationState>.Path>,
    action toStackAction: CasePath<Action, StackAction<DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _StackReducer<Self, Destination>
  where Destination.State == DestinationState, Destination.Action == DestinationAction {
    _StackReducer(
      base: self,
      toStackState: toStackState,
      toStackAction: toStackAction,
      destination: destination(),
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _StackReducer<
  Base: ReducerProtocol, Destination: ReducerProtocol
>: ReducerProtocol {
  let base: Base
  let toStackState: WritableKeyPath<Base.State, StackState<Destination.State>.Path>
  let toStackAction: CasePath<Base.Action, StackAction<Destination.Action>>
  let destination: Destination
  let file: StaticString
  let fileID: StaticString
  let line: UInt

  @Dependency(\.navigationID) var navigationID

  public func reduce(into state: inout Base.State, action: Base.Action) -> EffectTask<Base.Action> {
    // TODO: is there anything to do with inert state in here?

    let idsBefore = state[keyPath: self.toStackState].state._ids
    let destinationEffects: EffectTask<Base.Action>
    let baseEffects: EffectTask<Base.Action>

    switch self.toStackAction.extract(from: action) {
    case let .element(elementID, destinationAction):
      let id = self.navigationID(for: elementID)
      destinationEffects = self.destination
        .dependency(\.dismiss, DismissEffect { Task.cancel(id: DismissID(elementID: elementID)) })
        .dependency(\.navigationID, id)
        .reduce(
          into: &state[keyPath: self.toStackState].state._elements[elementID]!,
          action: destinationAction
        )
        .map { toStackAction.embed(.element(id: elementID, $0)) }
        .cancellable(id: id)
      baseEffects = self.base.reduce(into: &state, action: action)

    case let .pathChanged(pathChange):
      state[keyPath: self.toStackState].state._ids.elements = pathChange.ids
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)

    case let .popFrom(id):
      baseEffects = self.base.reduce(into: &state, action: action)
      destinationEffects = .none
      state[keyPath: self.toStackState].pop(from: id)

    case let .popTo(id):
      baseEffects = self.base.reduce(into: &state, action: action)
      destinationEffects = .none
      state[keyPath: self.toStackState].pop(to: id)

    case .popToRoot:
      baseEffects = self.base.reduce(into: &state, action: action)
      destinationEffects = .none
      state[keyPath: self.toStackState].state.removeAll()

    case let .present(presentedState):
      // TODO: ???
      guard let presentedState = presentedState as? Destination.State
      else {
        // TODO: Runtime warn
        return .none
      }
      let id = ElementID()
      state[keyPath: self.toStackState].state._ids.append(id)
      state[keyPath: self.toStackState].state._elements[id] = presentedState
      return .none

    case .none:
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
    }

    let idsAfter = state[keyPath: self.toStackState].state._ids

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
            await send(self.toStackAction.embed(.popFrom(id: elementID)))
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
      .appending(path: self.toStackState)
      .appending(component: elementID)
  }
}

private struct DismissID: Hashable {
  let elementID: ElementID
}
