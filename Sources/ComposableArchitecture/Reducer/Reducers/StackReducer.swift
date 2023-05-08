import Combine
import Foundation
import OrderedCollections

/// A list of data representing the content of a navigation stack.
///
/// Use this type for modeling a feature's domain that needs to present child features using
/// ``ReducerProtocol/forEach(_:action:destination:fileID:line:)``.
///
/// See the dedicated article on <doc:Navigation> for more information on the library's navigation
/// tools, and in particular see <doc:StackBasedNavigation> for information on modeling navigation
/// using ``StackState`` for navigation stacks.
public struct StackState<Element> {
  var _dictionary: OrderedDictionary<StackElementID, Element>
  fileprivate var _mounted: Set<StackElementID> = []

  @Dependency(\.stackElementID) private var stackElementID

  /// An ordered set of identifiers, one for each stack element.
  ///
  /// You can use this set to iterate over stack elements along with their associated identifiers.
  ///
  /// ```swift
  /// for (id, element) in zip(state.path.ids, state.path) {
  ///   if element.isDeleted {
  ///     state.path.pop(from: id)
  ///     break
  ///   }
  /// }
  /// ```
  public var ids: OrderedSet<StackElementID> {
    self._dictionary.keys
  }

  /// Accesses the value associated with the given id for reading and writing.
  public subscript(id id: StackElementID) -> Element? {
    _read { yield self._dictionary[id] }
    _modify {
      yield &self._dictionary[id]
      if !self._dictionary.keys.contains(id) {
        self._mounted.remove(id)
      }
    }
    set {
      // TODO: precondition(newValue == nil || self._dictionary[id] != nil)
      self._dictionary[id] = newValue
      if newValue == nil {
        self._mounted.remove(id)
      }
    }
  }

  /// Pops the element corresponding to `id` from the stack, and all elements after it.
  /// - Parameter id: The ID of an element in the stack.
  public mutating func pop(from id: StackElementID) {
    guard let index = self._dictionary.keys.firstIndex(of: id)
    else { return }
    for id in self._dictionary.keys[index...] {
      self._mounted.remove(id)
    }
    self._dictionary.removeSubrange(index...)
  }

  /// Pops all elements that come after the element corresponding to `id` in the stack.
  /// - Parameter id: The ID of an element in the stack.
  public mutating func pop(to id: StackElementID) {
    guard var index = self._dictionary.keys.firstIndex(of: id)
    else { return }
    index += 1
    for id in self._dictionary.keys[index...] {
      self._mounted.remove(id)
    }
    self._dictionary.removeSubrange(index...)
  }
}

extension StackState: RandomAccessCollection, RangeReplaceableCollection {
  public var startIndex: Int { self._dictionary.keys.startIndex }

  public var endIndex: Int { self._dictionary.keys.endIndex }

  public func index(after i: Int) -> Int { self._dictionary.keys.index(after: i) }

  public func index(before i: Int) -> Int { self._dictionary.keys.index(before: i) }

  public subscript(position: Int) -> Element { self._dictionary.values[position] }

  public init() {
    self._dictionary = [:]
  }

  public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
  where C.Element == Element {
    for id in self.ids[subrange] {
      self._mounted.remove(id)
    }
    self._dictionary.removeSubrange(subrange)
    for (offset, element) in zip(subrange.lowerBound..., newElements) {
      self._dictionary.updateValue(element, forKey: self.stackElementID.next(), insertingAt: offset)
    }
  }
}

extension StackState: Equatable where Element: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs._dictionary == rhs._dictionary
  }
}

extension StackState: Hashable where Element: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self._dictionary)
  }
}

// NB: We can remove `@unchecked` when swift-collections 1.1 is released.
extension StackState: @unchecked Sendable where Element: Sendable {}

extension StackState: Decodable where Element: Decodable {
  public init(from decoder: Decoder) throws {
    let elements = try [Element](from: decoder)
    self.init()
    self.append(contentsOf: elements)
  }
}

extension StackState: Encodable where Element: Encodable {
  public func encode(to encoder: Encoder) throws {
    try [Element](self).encode(to: encoder)
  }
}

// TODO: revisit
//extension StackState: CustomStringConvertible {
//  public var description: String {
//    self._dictionary.values.elements.description
//  }
//}
//
//extension StackState: CustomDebugStringConvertible {
//  public var debugDescription: String {
//    self._dictionary.values.elements.debugDescription
//  }
//}

extension StackState: CustomDumpReflectable {
  public var customDumpMirror: Mirror {
    Mirror(self, unlabeledChildren: Array(zip(self.ids, self)), displayStyle: .dictionary)
  }
}

/// A wrapper type for actions that can be presented in a navigation stack.
///
/// Use this type for modeling a feature's domain that needs to present child features using
/// ``ReducerProtocol/forEach(_:action:destination:fileID:line:)``.
///
/// See the dedicated article on <doc:Navigation> for more information on the library's navigation
/// tools, and in particular see <doc:StackBasedNavigation> for information on modeling navigation
/// using ``StackAction`` for navigation stacks.
public enum StackAction<State, Action> {
  /// An action sent to the associated stack element at a given identifier.
  indirect case element(id: StackElementID, action: Action)

  /// An action sent to dismiss the associated stack element at a given identifier.
  case popFrom(id: StackElementID)

  /// An action sent to present the given state at a given identifier in a navigation stack. This
  /// action is typically sent from the view via the `NavigationLink(value:)` initializer.
  case push(id: StackElementID, state: State)
}

extension StackAction: Equatable where State: Equatable, Action: Equatable {}
extension StackAction: Hashable where State: Hashable, Action: Hashable {}
extension StackAction: Sendable where State: Sendable, Action: Sendable {}

extension ReducerProtocol {
  /// Embeds a child reducer in a parent domain that works on elements of a navigation stack in
  /// parent state.
  ///
  /// For example, if a parent feature holds onto a ``StackState`` of destination states, then it
  /// can perform its core logic _and_ the destination's logic by using the `forEach` operator:
  ///
  /// - Parameters:
  ///   - toStackState: A writable key path from parent state to a stack of destination state.
  ///   - toStackAction: A case path from parent action to a stack action.
  ///   - destination: A reducer that will be invoked with destination actions against elements of
  ///     destination state.
  /// - Returns: A reducer that combines the destination reducer with the parent reducer.
  @inlinable
  @warn_unqualified_access
  public func forEach<DestinationState, DestinationAction, Destination: ReducerProtocol>(
    _ toStackState: WritableKeyPath<State, StackState<DestinationState>>,
    action toStackAction: CasePath<Action, StackAction<DestinationState, DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _StackReducer<Self, Destination>
  where Destination.State == DestinationState, Destination.Action == DestinationAction {
    _StackReducer(
      base: self,
      toStackState: toStackState,
      toStackAction: toStackAction,
      destination: destination(),
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
  let toStackAction: CasePath<Base.Action, StackAction<Destination.State, Destination.Action>>
  let destination: Destination
  let fileID: StaticString
  let line: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    base: Base,
    toStackState: WritableKeyPath<Base.State, StackState<Destination.State>>,
    toStackAction: CasePath<Base.Action, StackAction<Destination.State, Destination.Action>>,
    destination: Destination,
    fileID: StaticString,
    line: UInt
  ) {
    self.base = base
    self.toStackState = toStackState
    self.toStackAction = toStackAction
    self.destination = destination
    self.fileID = fileID
    self.line = line
  }

  public func reduce(into state: inout Base.State, action: Base.Action) -> EffectTask<Base.Action> {
    let idsBefore = state[keyPath: self.toStackState].ids
    let destinationEffects: EffectTask<Base.Action>
    let baseEffects: EffectTask<Base.Action>

    switch self.toStackAction.extract(from: action) {
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

    case let .popFrom(id):
      destinationEffects = .none
      let canPop = state[keyPath: self.toStackState].ids.contains(id)
      baseEffects = self.base.reduce(into: &state, action: action)
      state[keyPath: self.toStackState].pop(from: id)
      // TODO: write test to show that if base removes element we do not get runtime warn
      if !canPop {
        runtimeWarn("TODO")
      }

    case let .push(id, element):
      destinationEffects = .none
      if state[keyPath: self.toStackState].ids.contains(id) {
        runtimeWarn("TODO")
        baseEffects = .none
        break
      } else if DependencyValues._current.context == .test {
        if id.generation > DependencyValues._current.stackElementID.peek().generation {
          runtimeWarn("TODO")
        } else if id.generation == DependencyValues._current.stackElementID.peek().generation {
          _ = DependencyValues._current.stackElementID.next()
        }
      }
      state[keyPath: self.toStackState]._dictionary[id] = element
      baseEffects = self.base.reduce(into: &state, action: action)

    case .none:
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
    }

    let idsAfter = state[keyPath: self.toStackState].ids
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

/// An opaque type that identifies an element of ``StackState``.
public struct StackElementID: Hashable, Sendable {
  @_spi(Internals) public var generation: Int
  @_spi(Internals) public var rawValue: AnyHashableSendable

  @_spi(Internals) public init<RawValue: Hashable & Sendable>(generation: Int, rawValue: RawValue) {
    self.generation = generation
    self.rawValue = AnyHashableSendable(rawValue)
  }

  // TODO: is this still correct? can we get test coverage that breaks when || is changed to && ?
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue == rhs.rawValue || lhs.generation == rhs.generation
  }
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
    if !_XCTIsTesting {
      fatalError(
        """
        Specifying stack element IDs by integer literal is not allowed outside of tests.

        In tests, integer literal stack element IDs can be used as a shorthand to the \
        auto-incrementing generation of the current dependency context. This can be useful when \
        asserting against actions received by a specific element.
        """
      )
    }
    self.init(generation: value, rawValue: value)
  }
}

private struct NavigationDismissID: Hashable {
  let elementID: AnyHashable  // TODO: rename
}
