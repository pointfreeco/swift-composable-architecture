import Foundation
import OrderedCollections

public struct StackElementID: DependencyKey, Sendable {
  public let next: @Sendable () -> AnyHashable
  public let peek: @Sendable () -> AnyHashable

  public func callAsFunction() -> AnyHashable {
    self.next()
  }

  public static var liveValue: Self {
    let next = LockIsolated(UUID())
    return Self(
      next: {
        defer { next.setValue(UUID()) }
        return next.value
      },
      peek: { next.value }
    )
  }

  public static var testValue: Self {
    let next = LockIsolated(0)
    return Self(
      next: {
        defer { next.withValue { $0 += 1 } }
        return next.value
      },
      peek: { next.value }
    )
  }
}
extension DependencyValues {
  public var stackElementID: StackElementID {
    get { self[StackElementID.self] }
    set { self[StackElementID.self] = newValue }
  }
}


// TODO: Better name? `DestinationID`? `StackElementID`?
//public struct ElementID: Hashable, Sendable {
//  fileprivate let id = UUID()
//  fileprivate var index: Int? = nil
//}

@propertyWrapper
public struct StackState<
  State
>: BidirectionalCollection, MutableCollection, RandomAccessCollection, RangeReplaceableCollection {
  var _ids: OrderedSet<AnyHashable>
  var _elements: [AnyHashable: State]  // TODO: [ElementID: (state: State, isPresented: Bool)]

  public var startIndex: Int { self._ids.startIndex }

  public var endIndex: Int { self._ids.endIndex }

  public func index(after i: Int) -> Int { self._ids.index(after: i) }

  public func index(before i: Int) -> Int { self._ids.index(before: i) }

  public subscript(position: Int) -> State {
    _read { yield self._elements[self._ids[position]]! }
    _modify { yield &self._elements[self._ids[position]]! }
  }

  // return .fireAndForget { router.popToRoot() }

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
      let id = DependencyValues._current.stackElementID.next()
      self._ids.insert(id, at: subrange.startIndex)
      self._elements[id] = element
    }
  }

  public struct Path {
    var state: StackState

    public var ids: [AnyHashable] {
      self.state._ids.elements
    }

    public subscript(id id: AnyHashable) -> State {
      _read { yield self.state._elements[id]! }
      _modify { yield &self.state._elements[id]! }
    }

    subscript(safeID id: AnyHashable) -> State? {
      _read { yield self.state._elements[id] }
      _modify { yield &self.state._elements[id] }
    }

    @discardableResult
    public mutating func remove(id: AnyHashable) -> State {
      self.state._ids.remove(id)
      return self.state._elements.removeValue(forKey: id)!
    }

    public mutating func pop(from id: AnyHashable) {
      let index = self.state._ids.firstIndex(of: id)! + 1
      for id in self.state._ids[index...] {
        self.state._elements[id] = nil
      }
      self.state._ids.removeSubrange(index...)
    }

    public mutating func pop(to id: AnyHashable) {
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

public struct StackAction<Action> {
  let action: AccessControlAction

  init(_ action: AccessControlAction) {
    self.action = action
  }

  public static func delete(_ indexSet: IndexSet) -> Self {
    self.init(.internal(.delete(indexSet)))
  }

  public static func element(id: AnyHashable, action: Action) -> Self {
    self.init(.public(.element(id: id, action: action)))
  }

  public static func popFrom(id: AnyHashable) -> Self {
    self.init(.internal(.popFrom(id: id)))
  }

  public static func popTo(id: AnyHashable) -> Self {
    self.init(.internal(.popTo(id: id)))
  }

  public static var popToRoot: Self {
    self.init(.internal(.popToRoot))
  }
  
  public var type: PublicAction {
    guard case let .public(type) = self.action else {
      // TODO: This can be happen, _e.g._, if you construct `.delete(indexSet)` and invoke `.type`.
      fatalError()
    }
    return type
  }

  public enum PublicAction {
    case didAdd(id: AnyHashable)
    case element(id: AnyHashable, action: Action)
    // TODO: Possible to present arbitrary state in a lightweight way?
    case present(Any)
    case willRemove(id: AnyHashable)
  }

  enum InternalAction: Hashable {
    case delete(IndexSet)
    case pathChanged(ids: [AnyHashable])
    case popFrom(id: AnyHashable)
    case popTo(id: AnyHashable)
    case popToRoot  // TODO: `removeAll`?
  }

  enum AccessControlAction {
    case `public`(PublicAction)
    case `internal`(InternalAction)
  }
}

extension StackAction.PublicAction: Equatable where Action: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case let (.didAdd(lhs), .didAdd(rhs)):
      return lhs == rhs
    case let (.element(lhsID, lhsAction), .element(rhsID, rhsAction)):
      return lhsID == rhsID && lhsAction == rhsAction
    case let (.present(lhs), .present(rhs)):
      return _isEqual(lhs, rhs)
        ?? {
          #if DEBUG
            let lhsType = type(of: lhs)
            if TaskResultDebugging.emitRuntimeWarnings, lhsType == type(of: rhs) {
              let lhsTypeName = typeName(lhsType)
              runtimeWarn(
                """
                "\(lhsTypeName)" is not equatable. …

                To test two values of this type, it must conform to the "Equatable" protocol. For \
                example:

                    extension \(lhsTypeName): Equatable {}

                See the documentation of "NavigationAction" for more information.
                """
              )
            }
          #endif
          return false
        }()

    case let (.willRemove(lhs), .willRemove(rhs)):
      return lhs == rhs

    case (.didAdd, _), (.element, _), (.present, _), (.willRemove, _):
      return false
    }
  }
}

extension StackAction.PublicAction: Hashable where Action: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self {
    case let .didAdd(id: id):
      hasher.combine(0)
      hasher.combine(id)
    case let .element(id: id, action):
      hasher.combine(1)
      hasher.combine(id)
      hasher.combine(action)
    case let .present(state):
      guard let state = (state as Any) as? AnyHashable
      else {
        #if DEBUG
          if TaskResultDebugging.emitRuntimeWarnings {
            let stateType = typeName(type(of: state))
            runtimeWarn(
              """
              "\(stateType)" is not hashable. …

              To hash a value of this type, it must conform to the "Hashable" protocol. For example:

                  extension \(stateType): Hashable {}

              See the documentation of "NavigationAction" for more information.
              """
            )
          }
        #endif
        return
      }
      hasher.combine(3)
      hasher.combine(state)
    case let .willRemove(id: id):
      hasher.combine(2)
      hasher.combine(id)
    }
  }
}

extension StackAction.AccessControlAction: Equatable where Action: Equatable {}
extension StackAction.AccessControlAction: Hashable where Action: Hashable {}
extension StackAction: Equatable where Action: Equatable {}
extension StackAction: Hashable where Action: Hashable {}

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

    switch self.toStackAction.extract(from: action)?.action {
    case let .internal(.delete(indexSet)):
      baseEffects = .merge(
        indexSet.map { state[keyPath: self.toStackState].state._ids[$0] }.map { id in
          self.base.reduce(
            into: &state,
            action: self.toStackAction.embed(StackAction(.public(.willRemove(id: id))))
          )
        }
      )
      destinationEffects = .none
      state[keyPath: self.toStackState].state.remove(atOffsets: indexSet)

    case let .internal(.pathChanged(ids)):
      baseEffects = .merge(
        state[keyPath: self.toStackState].state._ids.subtracting(ids).map { id in
          self.base.reduce(
            into: &state,
            action: self.toStackAction.embed(StackAction(.public(.willRemove(id: id))))
          )
        }
      )
      destinationEffects = .none
      state[keyPath: self.toStackState].state._ids.elements = ids

    case let .internal(.popFrom(id)):
      let index = state[keyPath: self.toStackState].state._ids.firstIndex(of: id)!
      baseEffects = .merge(
        state[keyPath: self.toStackState].state._ids[index...].map { id in
          self.base.reduce(
            into: &state,
            action: self.toStackAction.embed(StackAction(.public(.willRemove(id: id))))
          )
        }
      )
      destinationEffects = .none
      state[keyPath: self.toStackState].pop(from: id)

    case let .internal(.popTo(id)):
      let index = state[keyPath: self.toStackState].state._ids.firstIndex(of: id)! + 1
      baseEffects = .merge(
        state[keyPath: self.toStackState].state._ids[index...].map { id in
          self.base.reduce(
            into: &state,
            action: self.toStackAction.embed(StackAction(.public(.willRemove(id: id))))
          )
        }
      )
      destinationEffects = .none
      state[keyPath: self.toStackState].pop(to: id)

    case .internal(.popToRoot):
      baseEffects = .merge(
        state[keyPath: self.toStackState].state._ids.map { id in
          self.base.reduce(
            into: &state,
            action: self.toStackAction.embed(StackAction(.public(.willRemove(id: id))))
          )
        }
      )
      destinationEffects = .none
      state[keyPath: self.toStackState].state.removeAll()

    case .public(.didAdd):
      return .none

    case let .public(.element(elementID, destinationAction)):
      let id = self.navigationID(for: elementID)
      destinationEffects = self.destination
        .dependency(\.dismiss, DismissEffect { Task.cancel(id: DismissID(elementID: elementID)) })
        .dependency(\.navigationID, id)
        .reduce(
          into: &state[keyPath: self.toStackState].state._elements[elementID]!,
          action: destinationAction
        )
        .map { toStackAction.embed(.element(id: elementID, action: $0)) }
        .cancellable(id: id)
      baseEffects = self.base.reduce(into: &state, action: action)

    case let .public(.present(presentedState)):
      // TODO: possible to check if presentedState is embeddable inside
      guard let presentedState = presentedState as? Destination.State
      else {
        // TODO: Runtime warn
        return .none
      }
      let id = DependencyValues._current.stackElementID.next()
      state[keyPath: self.toStackState].state._ids.append(id)
      state[keyPath: self.toStackState].state._elements[id] = presentedState
      return .none

    case .public(.willRemove):
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
        return .merge(
          .run { send in
            do {
              try await withDependencies {
                $0.navigationID = id
              } operation: {
                try await withTaskCancellation(id: DismissID(elementID: elementID)) {
                  try await Task.never()
                }
              }
            } catch is CancellationError {
              await send(self.toStackAction.embed(StackAction(.internal(.popFrom(id: elementID)))))
            }
          }
            .cancellable(id: id),
          self.base.reduce(
            into: &state,
            action: self.toStackAction.embed(StackAction(.public(.didAdd(id: elementID))))
          )
        )
      }
    )

    return .merge(
      destinationEffects,
      baseEffects,
      cancelEffects,
      presentEffects
    )
  }

  private func navigationID(for elementID: AnyHashable) -> NavigationID {
    self.navigationID
      .appending(path: self.toStackState)
      .appending(component: elementID)
  }
}

private struct DismissID: Hashable {
  let elementID: AnyHashable // TODO: rename
}
