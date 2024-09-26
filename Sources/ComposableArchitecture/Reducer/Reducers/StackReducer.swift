@_spi(Reflection) import CasePaths
import Combine
import Foundation
import OrderedCollections

/// A list of data representing the content of a navigation stack.
///
/// Use this type for modeling a feature's domain that needs to present child features using
/// ``Reducer/forEach(_:action:destination:fileID:filePath:line:column:)-9svqb``.
///
/// See the dedicated article on <doc:Navigation> for more information on the library's navigation
/// tools, and in particular see <doc:StackBasedNavigation> for information on modeling navigation
/// using ``StackState`` for navigation stacks. Also see
/// <doc:StackBasedNavigation#StackState-vs-NavigationPath> to understand how ``StackState``
/// compares to SwiftUI's `NavigationPath` type.
public struct StackState<Element> {
  var _dictionary: OrderedDictionary<StackElementID, Element>
  fileprivate var _mounted: OrderedSet<StackElementID> = []

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
  public subscript(
    id id: StackElementID,
    fileID fileID: _HashableStaticString = #fileID,
    filePath filePath: _HashableStaticString = #filePath,
    line line: UInt = #line,
    column column: UInt = #column
  ) -> Element? {
    _read { yield self._dictionary[id] }
    _modify { yield &self._dictionary[id] }
    set {
      switch (self.ids.contains(id), newValue, isTesting) {
      case (true, _, _), (false, .some, true):
        self._dictionary[id] = newValue
      case (false, .some, false):
        if !isTesting {
          reportIssue(
            "Can't assign element at missing ID.",
            fileID: fileID.rawValue,
            filePath: filePath.rawValue,
            line: line,
            column: column
          )
        }
      case (false, .none, _):
        break
      }
    }
  }

  /// Accesses the value associated with the given id and case for reading and writing.
  ///
  /// When using stack-based navigation (see <doc:StackBasedNavigation>) you will typically have a
  /// single enum that represents all of the destinations that can be pushed onto the stack, and you
  /// will hold that state in ``StackState``:
  ///
  /// ```swift
  /// struct State {
  ///   var path = StackState<Path.State>()
  /// }
  /// ```
  ///
  /// You can use this subscript for a succinct syntax to modify the data in a particular case of
  /// the `Path.State` enum, like so:
  ///
  /// ```swift
  /// state.path[id: 0, case: \.edit]?.alert = AlertState {
  ///   Text("Delete?")
  /// }
  /// ```
  ///
  /// > Important: Accessing the wrong case will result in a runtime warning and test failure.
  public subscript<Case>(id id: StackElementID, case path: CaseKeyPath<Element, Case>) -> Case?
  where Element: CasePathable {
    _read { yield self[id: id, case: AnyCasePath(path)] }
    _modify { yield &self[id: id, case: AnyCasePath(path)] }
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  public subscript<Case>(
    id id: StackElementID,
    case path: AnyCasePath<Element, Case>,
    fileID fileID: _HashableStaticString = #fileID,
    filePath filePath: _HashableStaticString = #filePath,
    line line: UInt = #line,
    column column: UInt = #column
  ) -> Case? {
    _read { yield self[id: id].flatMap(path.extract) }
    _modify {
      let root = self[id: id]
      var value = root.flatMap(path.extract)
      let success = value != nil
      yield &value
      guard success else {
        var description: String?
        if let root = root,
          let metadata = EnumMetadata(Element.self),
          let caseName = metadata.caseName(forTag: metadata.tag(of: root))
        {
          description = caseName
        }
        reportIssue(
          """
          Can't modify unrelated case\(description.map { " \($0.debugDescription)" } ?? "")
          """,
          fileID: fileID.rawValue,
          filePath: filePath.rawValue,
          line: line,
          column: column
        )
        return
      }
      self[id: id] = value.map(path.embed)
    }
  }

  /// Pops the element corresponding to `id` from the stack, and all elements after it.
  ///
  /// - Parameter id: The identifier of an element in the stack.
  public mutating func pop(from id: StackElementID) {
    guard let index = self.ids.firstIndex(of: id)
    else { return }
    self.removeSubrange(index...)
  }

  /// Pops all elements that come after the element corresponding to `id` in the stack.
  ///
  /// - Parameter id: The identifier of an element in the stack.
  public mutating func pop(to id: StackElementID) {
    guard let index = self.ids.firstIndex(of: id)
    else { return }
    self.removeSubrange(index.advanced(by: 1)...)
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
  public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
    self._dictionary.removeAll(keepingCapacity: keepCapacity)
  }
  public mutating func replaceSubrange(
    _ subrange: Range<Int>, with newElements: some Collection<Element>
  ) {
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

extension StackState: Sendable where Element: Sendable {}

extension StackState: Decodable where Element: Decodable {
  public init(from decoder: any Decoder) throws {
    let elements = try [Element](from: decoder)
    self.init(elements)
  }
}

extension StackState: Encodable where Element: Encodable {
  public func encode(to encoder: any Encoder) throws {
    try [Element](self).encode(to: encoder)
  }
}

extension StackState: CustomStringConvertible {
  public var description: String {
    self._dictionary.values.elements.description
  }
}

extension StackState: CustomDebugStringConvertible {
  public var debugDescription: String {
    "\(Self.self)(\(self._dictionary.description))"
  }
}

extension StackState: CustomDumpReflectable {
  public var customDumpMirror: Mirror {
    Mirror(self, unlabeledChildren: Array(zip(self.ids, self)), displayStyle: .dictionary)
  }
}

/// A wrapper type for actions that can be presented in a navigation stack.
///
/// Use this type for modeling a feature's domain that needs to present child features using
/// ``Reducer/forEach(_:action:destination:fileID:filePath:line:column:)-9svqb``.
///
/// See the dedicated article on <doc:Navigation> for more information on the library's navigation
/// tools, and in particular see <doc:StackBasedNavigation> for information on modeling navigation
/// using ``StackAction`` for navigation stacks.
public enum StackAction<State, Action>: CasePathable {
  /// An action sent to the associated stack element at a given identifier.
  indirect case element(id: StackElementID, action: Action)

  /// An action sent to dismiss the associated stack element at a given identifier.
  case popFrom(id: StackElementID)

  /// An action sent to present the given state at a given identifier in a navigation stack. This
  /// action is typically sent from the view via the `NavigationLink(value:)` initializer.
  case push(id: StackElementID, state: State)

  public static var allCasePaths: AllCasePaths {
    AllCasePaths()
  }

  public struct AllCasePaths {
    public var element: AnyCasePath<StackAction, (id: StackElementID, action: Action)> {
      AnyCasePath(
        embed: { .element(id: $0, action: $1) },
        extract: {
          guard case let .element(id, action) = $0 else { return nil }
          return (id: id, action: action)
        }
      )
    }

    public var popFrom: AnyCasePath<StackAction, StackElementID> {
      AnyCasePath(
        embed: { .popFrom(id: $0) },
        extract: {
          guard case let .popFrom(id) = $0 else { return nil }
          return id
        }
      )
    }

    public var push: AnyCasePath<StackAction, (id: StackElementID, state: State)> {
      AnyCasePath(
        embed: { .push(id: $0, state: $1) },
        extract: {
          guard case let .push(id, state) = $0 else { return nil }
          return (id: id, state: state)
        }
      )
    }

    public subscript(id id: StackElementID) -> AnyCasePath<StackAction, Action> {
      AnyCasePath(
        embed: { .element(id: id, action: $0) },
        extract: {
          guard case .element(id, let action) = $0 else { return nil }
          return action
        }
      )
    }
  }
}

extension StackAction: Equatable where State: Equatable, Action: Equatable {}
extension StackAction: Hashable where State: Hashable, Action: Hashable {}
extension StackAction: Sendable where State: Sendable, Action: Sendable {}

extension Reducer {
  /// Embeds a child reducer in a parent domain that works on elements of a navigation stack in
  /// parent state.
  ///
  /// This version of `forEach` works when the parent domain holds onto the child domain using
  /// ``StackState`` and ``StackAction``.
  ///
  /// For example, if a parent feature models a navigation stack of child features using the
  /// ``StackState`` and ``StackAction`` types, then it can perform its core logic _and_ the logic
  /// of each child feature using the `forEach` operator:
  ///
  /// ```swift
  /// @Reducer
  /// struct ParentFeature {
  ///   struct State {
  ///     var path = StackState<Path.State>()
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case path(StackActionOf<Path>)
  ///     // ...
  ///   }
  ///   var body: some ReducerOf<Self> {
  ///     Reduce { state, action in
  ///       // Core parent logic
  ///     }
  ///     .forEach(\.path, action: \.path) {
  ///       Path()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// The `forEach` operator does a number of things to make integrating parent and child features
  /// ergonomic and enforce correctness:
  ///
  ///   * It forces a specific order of operations for the child and parent features:
  ///     * When a ``StackAction/element(id:action:)`` action is sent it runs the
  ///       child first, and then the parent. If the order was reversed, then it would be possible
  ///       for the parent feature to `nil` out the child state, in which case the child feature
  ///       would not be able to react to that action. That can cause subtle bugs.
  ///     * When a ``StackAction/popFrom(id:)`` action is sent it runs the parent feature
  ///       before the child state is popped off the stack. This gives the parent feature an
  ///       opportunity to inspect the child state one last time before the state is removed.
  ///     * When a ``StackAction/push(id:state:)`` action is sent it runs the parent feature
  ///       after the child state is appended to the stack. This gives the parent feature an
  ///       opportunity to make extra mutations to the state after it has been added.
  ///
  ///   * It automatically cancels all child effects when it detects the child's state is removed
  ///     from the stack
  ///
  ///   * It gives the child feature access to the ``DismissEffect`` dependency, which allows the
  ///     child feature to dismiss itself without communicating with the parent.
  ///
  /// - Parameters:
  ///   - toStackState: A writable key path from parent state to a stack of destination state.
  ///   - toStackAction: A case path from parent action to a stack action.
  ///   - destination: A reducer that will be invoked with destination actions against elements of
  ///     destination state.
  /// - Returns: A reducer that combines the destination reducer with the parent reducer.
  @inlinable
  @warn_unqualified_access
  public func forEach<
    DestinationState, DestinationAction, Destination: Reducer<DestinationState, DestinationAction>
  >(
    _ toStackState: WritableKeyPath<State, StackState<DestinationState>>,
    action toStackAction: CaseKeyPath<Action, StackAction<DestinationState, DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> some Reducer<State, Action> {
    _StackReducer(
      base: self,
      toStackState: toStackState,
      toStackAction: AnyCasePath(toStackAction),
      destination: destination(),
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @inlinable
  @warn_unqualified_access
  public func forEach<
    DestinationState, DestinationAction, Destination: Reducer<DestinationState, DestinationAction>
  >(
    _ toStackState: WritableKeyPath<State, StackState<DestinationState>>,
    action toStackAction: AnyCasePath<Action, StackAction<DestinationState, DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> some Reducer<State, Action> {
    _StackReducer(
      base: self,
      toStackState: toStackState,
      toStackAction: toStackAction,
      destination: destination(),
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }
}

/// A convenience type alias for referring to a stack action of a given reducer's domain.
///
/// Instead of specifying two generics:
///
/// ```swift
///     case path(StackAction<Path.State, Path.Action>)
/// ```
///
/// You can specify a single generic:
///
/// ```swift
///     case path(StackActionOf<Path>)
/// ```
public typealias StackActionOf<R: Reducer> = StackAction<R.State, R.Action>

public struct _StackReducer<Base: Reducer, Destination: Reducer>: Reducer {
  let base: Base
  let toStackState: WritableKeyPath<Base.State, StackState<Destination.State>>
  let toStackAction: AnyCasePath<Base.Action, StackAction<Destination.State, Destination.Action>>
  let destination: Destination
  let fileID: StaticString
  let filePath: StaticString
  let line: UInt
  let column: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    base: Base,
    toStackState: WritableKeyPath<Base.State, StackState<Destination.State>>,
    toStackAction: AnyCasePath<Base.Action, StackAction<Destination.State, Destination.Action>>,
    destination: Destination,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
    self.base = base
    self.toStackState = toStackState
    self.toStackAction = toStackAction
    self.destination = destination
    self.fileID = fileID
    self.filePath = filePath
    self.line = line
    self.column = column
  }

  public func reduce(into state: inout Base.State, action: Base.Action) -> Effect<Base.Action> {
    let idsBefore = state[keyPath: self.toStackState]._mounted
    let destinationEffects: Effect<Base.Action>
    let baseEffects: Effect<Base.Action>

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
          .map { [toStackAction] in toStackAction.embed(.element(id: elementID, action: $0)) }
          ._cancellable(navigationIDPath: elementNavigationIDPath)
      } else {
        reportIssue(
          """
          A "forEach" at "\(self.fileID):\(self.line)" received an action for a missing element. …

            Action:
              \(debugCaseOutput(destinationAction))

          This is generally considered an application logic error, and can happen for a few reasons:

          • A parent reducer removed an element with this ID before this reducer ran. This reducer \
          must run before any other reducer removes an element, which ensures that element \
          reducers can handle their actions while their state is still available.

          • An in-flight effect emitted this action when state contained no element at this ID. \
          While it may be perfectly reasonable to ignore this action, consider canceling the \
          associated effect before an element is removed, especially if it is a long-living effect.

          • This action was sent to the store while its state contained no element at this ID. To \
          fix this make sure that actions for this reducer can only be sent from a store when \
          its state contains an element at this id. In SwiftUI applications, use \
          "NavigationStack.init(path:)" with a binding to a store.
          """,
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
        destinationEffects = .none
      }

      baseEffects = self.base.reduce(into: &state, action: action)

    case let .popFrom(id):
      destinationEffects = .none
      let canPop = state[keyPath: self.toStackState].ids.contains(id)
      baseEffects = self.base.reduce(into: &state, action: action)
      if canPop {
        state[keyPath: self.toStackState].pop(from: id)
      } else {
        reportIssue(
          """
          A "forEach" at "\(self.fileID):\(self.line)" received a "popFrom" action for a missing \
          element. …

            ID:
              \(id)
            Path IDs:
              \(state[keyPath: self.toStackState].ids)
          """,
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
      }

    case let .push(id, element):
      destinationEffects = .none
      if state[keyPath: self.toStackState].ids.contains(id) {
        reportIssue(
          """
          A "forEach" at "\(self.fileID):\(self.line)" received a "push" action for an element it \
          already contains. …

            ID:
              \(id)
            Path IDs:
              \(state[keyPath: self.toStackState].ids)
          """,
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
        baseEffects = self.base.reduce(into: &state, action: action)
        break
      } else if DependencyValues._current.context == .test {
        let nextID = DependencyValues._current.stackElementID.peek()
        if id.generation > nextID.generation {
          reportIssue(
            """
            A "forEach" at "\(self.fileID):\(self.line)" received a "push" action with an \
            unexpected generational ID. …

              Received ID:
                \(id)
              Expected ID:
                \(nextID)
            """,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
          )
        } else if id.generation == nextID.generation {
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

    let cancelEffects: Effect<Base.Action> =
      areOrderedSetsDuplicates(idsBefore, idsAfter)
      ? .none
      : .merge(
        idsBefore.subtracting(idsAfter).map {
          ._cancel(navigationID: self.navigationIDPath(for: $0))
        }
      )
    let presentEffects: Effect<Base.Action> =
      areOrderedSetsDuplicates(idsBefore, idsAfter)
      ? .none
      : .merge(
        idsAfter.subtracting(idsBefore).map { elementID in
          let navigationDestinationID = self.navigationIDPath(for: elementID)
          return .concatenate(
            .publisher { Empty(completeImmediately: false) }
              ._cancellable(
                id: NavigationDismissID(elementID: elementID),
                navigationIDPath: navigationDestinationID
              ),
            .publisher { Just(self.toStackAction.embed(.popFrom(id: elementID))) }
          )
          ._cancellable(navigationIDPath: navigationDestinationID)
          ._cancellable(id: OnFirstAppearID(), navigationIDPath: .init())
        }
      )

    state[keyPath: self.toStackState]._mounted = idsAfter

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
///
/// The ``StackState`` type creates instances of this identifier when new elements are added to
/// the stack. This makes it possible to easily look up specific elements in the stack without
/// resorting to positional indices, which can be error prone, especially when dealing with async
/// effects.
///
/// In production environments (e.g. in Xcode previews, simulators and on devices) the identifier
/// is backed by a randomly generated UUID, but in tests a deterministic, generational ID is used.
/// This allows you to predict how IDs will be created and allows you to write tests for how
/// features behave in the stack.
///
/// ```swift
/// @Test
/// func basics() {
///   var path = StackState<Int>()
///   path.append(42)
///   XCTAssertEqual(path[id: 0], 42)
///   path.append(1729)
///   XCTAssertEqual(path[id: 1], 1729)
///
///   path.removeAll()
///   path.append(-1)
///   XCTAssertEqual(path[id: 2], -1)
/// }
/// ```
///
/// Notice that after removing all elements and appending a new element, the ID generated was 2 and
/// did not go back to 0. This is because in tests the IDs are _generational_, which means they
/// keep counting up, even if you remove elements from the stack.
public struct StackElementID: Hashable, Sendable {
  @_spi(Internals) public var generation: Int

  @_spi(Internals) public init(generation: Int) {
    self.generation = generation
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
    if !isTesting {
      fatalError(
        """
        Specifying stack element IDs by integer literal is not allowed outside of tests.

        In tests, integer literal stack element IDs can be used as a shorthand to the \
        auto-incrementing generation of the current dependency context. This can be useful when \
        asserting against actions received by a specific element.
        """
      )
    }
    self.init(generation: value)
  }
}

private struct NavigationDismissID: Hashable, Sendable {
  private let elementID: AnyHashableSendable

  init(elementID: some Hashable & Sendable) {
    self.elementID = AnyHashableSendable(elementID)
  }
}
