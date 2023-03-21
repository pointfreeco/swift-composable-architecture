import Combine
import Foundation
import OrderedCollections

public struct StackElementID: Hashable {
  var generation: UInt
  var rawValue: AnyHashable
}

struct StackElementIDGenerator: DependencyKey, Sendable {
  let next: @Sendable () -> StackElementID
  let peek: @Sendable () -> StackElementID

  func callAsFunction() -> StackElementID {
    self.next()
  }

  static var liveValue: Self {
    let next = LockIsolated(StackElementID(generation: 0, rawValue: UUID()))
    return Self(
      next: {
        defer {
          next.withValue { $0 = StackElementID(generation: $0.generation + 1, rawValue: UUID()) }
        }
        return next.value
      },
      peek: { next.value }
    )
  }

  static var testValue: Self {
    let next = LockIsolated(StackElementID(generation: 0, rawValue: 0))
    return Self(
      next: {
        defer {
          next.withValue {
            $0 = StackElementID(generation: $0.generation + 1, rawValue: $0.generation + 1)
          }
        }
        return next.value
      },
      peek: { next.value }
    )
  }
}

extension DependencyValues {
  var stackElementID: StackElementIDGenerator {
    get { self[StackElementIDGenerator.self] }
    set { self[StackElementIDGenerator.self] = newValue }
  }
}

public struct StackState<
  Element
>: BidirectionalCollection, MutableCollection, RandomAccessCollection, RangeReplaceableCollection {
  fileprivate private(set) var _ids: OrderedSet<StackElementID>
  private var _elements: [StackElementID: Element]
  fileprivate var _mounted: Set<StackElementID> = []

  public internal(set) var ids: [StackElementID] {
    get { self._ids.elements }
    set {
      assert(newValue.allSatisfy { self._ids.contains($0) })
      let oldValue = self._ids.subtracting(newValue)
      self._ids.elements = newValue
      for id in oldValue {
        self._elements[id] = nil
        self._mounted.remove(id)
      }
    }
  }

  public subscript(id id: StackElementID) -> Element {
    _read { yield self._elements[id]! }
    _modify { yield &self._elements[id]! }
  }

  subscript(_id id: StackElementID) -> Element? {
    _read { yield self._elements[id] }
    _modify { yield &self._elements[id] }
  }

  @discardableResult
  public mutating func remove(id: StackElementID) -> Element {
    self._ids.remove(id)
    self._mounted.remove(id)
    return self._elements.removeValue(forKey: id)!
  }

  public mutating func pop(from id: StackElementID) {
    let index = self._ids.firstIndex(of: id)! + 1
    for id in self._ids[index...] {
      self._elements[id] = nil
      self._mounted.remove(id)
    }
    self._ids.removeSubrange(index...)
  }

  public mutating func pop(to id: StackElementID) {
    let index = self._ids.firstIndex(of: id)!
    for id in self._ids[index...] {
      self._elements[id] = nil
      self._mounted.remove(id)
    }
    self._ids.removeSubrange(index...)
  }

  public var startIndex: Int { self._ids.startIndex }

  public var endIndex: Int { self._ids.endIndex }

  public func index(after i: Int) -> Int { self._ids.index(after: i) }

  public func index(before i: Int) -> Int { self._ids.index(before: i) }

  public subscript(position: Int) -> Element {
    _read { yield self._elements[self._ids[position]]! }
    _modify { yield &self._elements[self._ids[position]]! }
  }

  public init() {
    self._ids = []
    self._elements = [:]
  }

  public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
  where Element == C.Element {
    for id in self._ids[subrange] {
      self._elements[id] = nil
      self._mounted.remove(id)
    }
    self._ids.removeSubrange(subrange)
    for element in newElements.reversed() {
      let id = DependencyValues._current.stackElementID.next()
      self._ids.insert(id, at: subrange.startIndex)
      self._elements[id] = element
    }
  }
}

extension StackState: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }
}

extension StackState: Equatable where Element: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.elementsEqual(rhs)
  }
}

extension StackState: Hashable where Element: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.count)
    for id in self.ids {
      hasher.combine(self[id: id])
    }
  }
}

extension StackState: Decodable where Element: Decodable {
  public init(from decoder: Decoder) throws {
    try self.init([Element](from: decoder))
  }
}

extension StackState: Encodable where Element: Encodable {
  public func encode(to encoder: Encoder) throws {
    try [Element](self).encode(to: encoder)
  }
}

extension StackState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: [Element](self))
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

  public static func element(id: StackElementID, action: Action) -> Self {
    self.init(.public(.element(id: id, action: action)))
  }

  public static func popFrom(id: StackElementID) -> Self {
    self.init(.internal(.popFrom(id: id)))
  }

  public static func popTo(id: StackElementID) -> Self {
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
    case didAdd(id: StackElementID)
    case element(id: StackElementID, action: Action)
    // TODO: Possible to present arbitrary state in a lightweight way?
    case present(Any)
    case willRemove(id: StackElementID)
  }

  enum InternalAction: Hashable {
    case delete(IndexSet)
    case pathChanged(ids: [StackElementID])
    case popFrom(id: StackElementID)
    case popTo(id: StackElementID)
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
    _ toStackState: WritableKeyPath<State, StackState<DestinationState>>,
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
  let toStackState: WritableKeyPath<Base.State, StackState<Destination.State>>
  let toStackAction: CasePath<Base.Action, StackAction<Destination.Action>>
  let destination: Destination
  let file: StaticString
  let fileID: StaticString
  let line: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  public func reduce(into state: inout Base.State, action: Base.Action) -> EffectTask<Base.Action> {
    // TODO: is there anything to do with ephemeral state in here?

    let idsBefore = state[keyPath: self.toStackState]._ids
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
      state[keyPath: self.toStackState].remove(atOffsets: indexSet)

    case let .internal(.pathChanged(ids)):
      baseEffects = .merge(
        state[keyPath: self.toStackState]._ids.subtracting(ids).map { id in
          self.base.reduce(
            into: &state,
            action: self.toStackAction.embed(StackAction(.public(.willRemove(id: id))))
          )
        }
      )
      destinationEffects = .none
      state[keyPath: self.toStackState].ids = ids

    case let .internal(.popFrom(id)):
      let index = state[keyPath: self.toStackState]._ids.firstIndex(of: id)!
      baseEffects = .merge(
        state[keyPath: self.toStackState]._ids[index...].map { id in
          self.base.reduce(
            into: &state,
            action: self.toStackAction.embed(StackAction(.public(.willRemove(id: id))))
          )
        }
      )
      destinationEffects = .none
      state[keyPath: self.toStackState].pop(from: id)

    case let .internal(.popTo(id)):
      let index = state[keyPath: self.toStackState]._ids.firstIndex(of: id)! + 1
      baseEffects = .merge(
        state[keyPath: self.toStackState]._ids[index...].map { id in
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
        state[keyPath: self.toStackState]._ids.map { id in
          self.base.reduce(
            into: &state,
            action: self.toStackAction.embed(StackAction(.public(.willRemove(id: id))))
          )
        }
      )
      destinationEffects = .none
      state[keyPath: self.toStackState].removeAll()

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
          into: &state[keyPath: self.toStackState][id: elementID],
          action: destinationAction
        )
        .map { toStackAction.embed(.element(id: elementID, action: $0)) }
        ._cancellable(navigationIDPath: elementNavigationIDPath)

      baseEffects = self.base.reduce(into: &state, action: action)

    case let .public(.present(presentedState)):
      // TODO: possible to check if presentedState is embeddable inside
      guard let presentedState = presentedState as? Destination.State
      else {
        // TODO: Runtime warn
        return .none
      }
      state[keyPath: self.toStackState].append(presentedState)
      return .none

    case .public(.willRemove):
      return .none

    case .none:
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
    }

    let idsAfter = state[keyPath: self.toStackState]._ids

    let cancelEffects = EffectTask<Base.Action>.merge(
      idsBefore.subtracting(idsAfter).map { ._cancel(navigationID: self.navigationIDPath(for: $0)) }
    )
    let presentEffects = EffectTask<Base.Action>.merge(
      idsAfter.subtracting(state[keyPath: self.toStackState]._mounted).map { elementID in
        let navigationDestinationID = self.navigationIDPath(for: elementID)
        state[keyPath: self.toStackState]._mounted.insert(elementID)
        return .merge(
            Empty(completeImmediately: false)
              .eraseToEffect(),
            self.base.reduce(
              into: &state,
              action: self.toStackAction.embed(StackAction(.public(.didAdd(id: elementID))))
            )
          )
          ._cancellable(
            id: NavigationDismissID(elementID: elementID),
            navigationIDPath: navigationDestinationID
          )
          .append(Just(self.toStackAction.embed(StackAction(.internal(.popFrom(id: elementID))))))
          .eraseToEffect()
          ._cancellable(navigationIDPath: navigationDestinationID)
          ._cancellable(id: OnFirstAppearID(), navigationIDPath: .init())
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
