import Combine
import Foundation
import OrderedCollections

public struct StackElementID: Hashable {
  var generation: Int
  var rawValue: AnyHashable
}

extension StackElementID: CustomDebugStringConvertible {
  public var debugDescription: String {
    "#\(self.generation)"
  }
}

extension StackElementID: CustomDumpStringConvertible {
  public var customDumpDescription: String {
    self.debugDescription
  }
}

extension StackElementID: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    // TODO: @Dep(\.stackElementID).peek() is UUID
    self.init(generation: value, rawValue: value)
  }
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

  func incrementingCopy() -> Self {
    let peek = self.peek()
    let next = LockIsolated(StackElementID(generation: peek.generation, rawValue: peek.generation))
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
  private(set) var _ids: OrderedSet<StackElementID>
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

  public subscript(id id: StackElementID) -> Element? {
    _read { yield self._elements[id] }
    _modify { yield &self._elements[id] }
  }

  @discardableResult
  public mutating func remove(id: StackElementID) -> Element? {
    self._ids.remove(id)
    self._mounted.remove(id)
    return self._elements.removeValue(forKey: id)
  }

  @discardableResult
  public mutating func pop(from id: StackElementID) -> Bool {
    guard let index = self._ids.firstIndex(of: id)
    else { return false }
    for id in self._ids[index...] {
      self._elements[id] = nil
      self._mounted.remove(id)
    }
    self._ids.removeSubrange(index...)
    return true
  }

  @discardableResult
  public mutating func pop(to id: StackElementID) -> Bool {
    guard var index = self._ids.firstIndex(of: id)
    else { return false }
    index += 1
    for id in self._ids[index...] {
      self._elements[id] = nil
      self._mounted.remove(id)
    }
    self._ids.removeSubrange(index...)
    return true
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

//  public mutating func swapAt(_ i: Int, _ j: Int) {
//    self._ids.swapAt(i, j)
//  }
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
    Mirror(self, unlabeledChildren: Array(zip(self.ids, self)), displayStyle: .dictionary)
  }
}

public enum StackAction<Action> {
  case element(id: StackElementID, action: Action)
  case popFrom(id: StackElementID)
}

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

    switch (self.toStackAction.extract(from: action)) {
    case let .popFrom(id):
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
      if !state[keyPath: self.toStackState].pop(from: id) {
        runtimeWarn("TODO")
      }

    case let .element(elementID, destinationAction):
      if state[keyPath: self.toStackState][id: elementID] != nil {
        let elementNavigationIDPath = self.navigationIDPath(for: elementID)
        destinationEffects = self.destination
          .dependency(
            \.dismiss,
             DismissEffect { @MainActor in
               Task._cancel(
                id: NavigationDismissID(elementID: elementID),
                navigationID: elementNavigationIDPath
               )
             }
          )
          .dependency(\.navigationIDPath, elementNavigationIDPath)
          .reduce(
            into: &state[keyPath: self.toStackState][id: elementID]!,
            action: destinationAction
          )
          .map { toStackAction.embed(.element(id: elementID, action: $0)) }
          ._cancellable(navigationIDPath: elementNavigationIDPath)
      } else {
        runtimeWarn("TODO")
        destinationEffects = .none
      }

      baseEffects = self.base.reduce(into: &state, action: action)

    case .none:
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
    }

    let idsAfter = state[keyPath: self.toStackState]._ids
    let idsMounted = state[keyPath: self.toStackState]._mounted

    let cancelEffects: EffectTask<Base.Action> =
      areOrderedSetsDuplicates(idsBefore, idsAfter)
      ? .none
      : .merge(
        idsBefore.subtracting(idsAfter).map {
          ._cancel(navigationID: self.navigationIDPath(for: $0))
        }
      )
    let presentEffects: EffectTask<Base.Action> =
      idsAfter.count == idsMounted.count
      ? .none
      : .merge(
        idsAfter.subtracting(idsMounted).map { elementID in
          let navigationDestinationID = self.navigationIDPath(for: elementID)
          state[keyPath: self.toStackState]._mounted.insert(elementID)
          return Empty(completeImmediately: false)
            .eraseToEffect()
            ._cancellable(
              id: NavigationDismissID(elementID: elementID),
              navigationIDPath: navigationDestinationID
            )
            .append(Just(self.toStackAction.embed(.popFrom(id: elementID))))
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

  private func navigationIDPath(for elementID: StackElementID) -> NavigationIDPath {
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
