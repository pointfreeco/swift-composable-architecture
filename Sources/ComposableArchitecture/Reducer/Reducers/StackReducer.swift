// TODO: Add effect cancellation to plain `.forEach(\.nonStackState)`
// TODO: Process of migrating a feature from `forEach(identifiedArray)` to `forEach(stack)`.

import Foundation
import OrderedCollections

public struct SomethingID {
  var id: AnyHashable // UInt
  var generation: UInt
}

public struct Generation:
  Comparable, ExpressibleByIntegerLiteral, Hashable, RawRepresentable, Sendable
{
  public let rawValue: UInt

  public init(_ value: UInt) {
    self.rawValue = value
  }

  public init(rawValue: UInt) {
    self.init(rawValue)
  }

  public init(integerLiteral value: UInt) {
    self.init(value)
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

public struct StackElementID: DependencyKey, Sendable {
  public let next: @Sendable () -> Generation
  public let peek: @Sendable () -> Generation

  public func callAsFunction() -> Generation {
    self.next()
  }

  private static var incrementing: Self {
    let next = LockIsolated(Generation(0))
    return Self(
      next: {
        defer { next.withValue { $0 = Generation($0.rawValue + 1) } }
        return next.value
      },
      peek: { next.value }
    )
  }

  public static var liveValue: Self { Self.incrementing }

  public static var testValue: Self { Self.incrementing }
}
extension DependencyValues {
  public var stackElementID: StackElementID {
    get { self[StackElementID.self] }
    set { self[StackElementID.self] = newValue }
  }
}

// TODO: Sketch out why we can't use IdentifiedArray
// TODO: Sketch out why we can't use OrderedDictionary or wrap it

@propertyWrapper
public struct StackState<
  State
>: BidirectionalCollection, MutableCollection, RandomAccessCollection, RangeReplaceableCollection {
  struct WrappedState {
    var state: State
    var didMount = false
  }

  var _ids: OrderedSet<Generation>
  var _elements: [Generation: WrappedState]

  public var startIndex: Int { self._ids.startIndex }

  public var endIndex: Int { self._ids.endIndex }

  public func index(after i: Int) -> Int { self._ids.index(after: i) }

  public func index(before i: Int) -> Int { self._ids.index(before: i) }

  public subscript(position: Int) -> State {
    _read { yield self._elements[self._ids[position]]!.state }
    _modify { yield &self._elements[self._ids[position]]!.state }
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
      self._elements[id] = WrappedState(state: element)
    }
  }

  public struct Path {
    var state: StackState

    public var ids: [Generation] {
      self.state._ids.elements
    }

    public subscript(id id: Generation) -> State {
      _read { yield self.state._elements[id]!.state }
      _modify { yield &self.state._elements[id]!.state }
    }

    subscript(safeID id: Generation) -> State? {
      _read { yield self.state._elements[id]?.state }
      _modify {
        var state = self.state._elements[id]?.state
        defer {
          if let state = state {
            self.state._elements[id]?.state = state
          }
        }
        yield &state
      }
    }

    @discardableResult
    public mutating func remove(id: Generation) -> State {
      self.state._ids.remove(id)
      return self.state._elements.removeValue(forKey: id)!.state
    }

    public mutating func pop(from id: Generation) {
      let index = self.state._ids.firstIndex(of: id)! + 1
      for id in self.state._ids[index...] {
        self.state._elements[id] = nil
      }
      self.state._ids.removeSubrange(index...)
    }

    public mutating func pop(to id: Generation) {
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
    lhs._ids.lazy.map { lhs._elements[$0]!.state }
      == rhs.wrappedValue._ids.lazy.map { rhs._elements[$0]!.state }
  }
}

extension StackState: Hashable where State: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.count)
    for id in self._ids {
      hasher.combine(self._elements[id]!.state)
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

  public static func element(id: Generation, action: Action) -> Self {
    self.init(.public(.element(id: id, action: action)))
  }

  public static func popFrom(id: Generation) -> Self {
    self.init(.internal(.popFrom(id: id)))
  }

  public static func popTo(id: Generation) -> Self {
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
    case didAdd(id: Generation)
    case element(id: Generation, action: Action)
    // TODO: Possible to present arbitrary state in a lightweight way?
    case present(Any)
    case willRemove(id: Generation)
  }

  enum InternalAction: Hashable {
    case delete(IndexSet)
    case pathChanged(ids: [Generation])
    case popFrom(id: Generation)
    case popTo(id: Generation)
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

  @Dependency(\.navigationIDPath) var navigationIDPath

  public func reduce(into state: inout Base.State, action: Base.Action) -> EffectTask<Base.Action> {
    // TODO: is there anything to do with inert state in here?

    let idsBefore = state[keyPath: self.toStackState].state._ids
    let destinationEffects: EffectTask<Base.Action>
    let baseEffects: EffectTask<Base.Action>

    switch self.toStackAction.extract(from: action)?.action {
    case let .internal(.delete(indexSet)):
      baseEffects = .merge(
        indexSet.map { state[keyPath: self.toStackState].ids[$0] }.map { id in
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
      // TODO: Need to clean up dictionary and remove elements that no longer exist
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
      let elementNavigationIDPath = self.navigationIDPath(for: elementID)
      destinationEffects = self.destination
        .dependency(
          \.dismiss,
          DismissEffect {
            Task._cancel(
              id: NavigationDismissID(elementID: elementID),
              navigationID: elementNavigationIDPath
            )
          }
        )
        .dependency(\.navigationIDPath, elementNavigationIDPath)
        .reduce(
          into: &state[keyPath: self.toStackState].state._elements[elementID]!.state,
          action: destinationAction
        )
        .map { toStackAction.embed(.element(id: elementID, action: $0)) }
        ._cancellable(id: _PresentedID(), navigationIDPath: elementNavigationIDPath)

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
      state[keyPath: self.toStackState].state._elements[id]!.state = presentedState
      return .none

    case .public(.willRemove):
      return .none

    case .none:
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
    }

    let idsAfter = state[keyPath: self.toStackState].state._ids

    let cancelEffects = EffectTask<Base.Action>.merge(
      idsBefore.subtracting(idsAfter).map { .cancel(id: self.navigationIDPath(for: $0)) }
    )
    // TODO: Update to use publisher style from presentation
    let presentEffects = EffectTask<Base.Action>.merge(
      idsAfter.subtracting(idsBefore).map { elementID in
        // TODO: `isPresented` logic from `PresentationState`
        let id = self.navigationIDPath(for: elementID)
        return .merge(
          .run { send in
            do {
              try await withDependencies {
                $0.navigationIDPath = id
              } operation: {
                try await withTaskCancellation(id: NavigationDismissID(elementID: elementID)) {
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

  private func navigationIDPath(for elementID: AnyHashable) -> NavigationIDPath {
    self.navigationIDPath.appending(
      NavigationID(
        id: elementID,
        keyPath: self.toStackState
      )
    )
  }
}

private struct NavigationDismissID: Hashable {
  let elementID: AnyHashable  // TODO: rename
}
