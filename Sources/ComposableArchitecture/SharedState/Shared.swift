import CustomDump
import Dependencies
import IssueReporting

#if canImport(Combine)
  import Combine
#endif

/// A property wrapper type that shares a value with multiple parts of an application.
///
/// See the <doc:SharingState> article for more detailed information on how to use this property
/// wrapper.
@dynamicMemberLookup
@propertyWrapper
public struct Shared<Value: Sendable>: Sendable {
  private let reference: any Reference
  private let keyPath: _SendableAnyKeyPath

  init(reference: any Reference, keyPath: _SendableAnyKeyPath) {
    self.reference = reference
    self.keyPath = keyPath
  }

  /// Wraps a value in a shared reference.
  ///
  /// - Parameters:
  ///   - value: A value to wrap.
  public init(_ value: Value, fileID: StaticString = #fileID, line: UInt = #line) {
    self.init(
      reference: ValueReference<Value, InMemoryKey<Value>>(
        initialValue: value,
        fileID: fileID,
        line: line
      ),
      keyPath: \Value.self
    )
  }

  /// Creates a shared reference from another shared reference.
  ///
  /// You don't call this initializer directly. Instead, Swift calls it for you when you use a
  /// property-wrapper attribute on a binding closure parameter.
  ///
  /// - Parameter projectedValue: A shared reference.
  public init(projectedValue: Shared) {
    self = projectedValue
  }

  /// Unwraps a shared reference to an optional value.
  ///
  /// ```swift
  /// @Shared(.currentUser) var currentUser: User?
  ///
  /// if let sharedCurrentUser = Shared($currentUser) {
  ///   sharedCurrentUser  // Shared<User>
  /// }
  /// ```
  ///
  /// - Parameter base: A shared reference to an optional value.
  public init?(_ base: Shared<Value?>) {
    guard let initialValue = base.wrappedValue
    else { return nil }
    self.init(
      reference: base.reference,
      // NB: Can get rid of bitcast when this is fixed:
      //     https://github.com/swiftlang/swift/issues/75531
      keyPath: (base.keyPath as AnyKeyPath)
        .appending(path: \Value?.[default: DefaultSubscript(initialValue)])!
        .unsafeSendable()
    )
  }

  /// Perform an operation on shared state with isolated access to the underlying value.
  @MainActor
  public func withLock<R>(_ transform: @Sendable (inout Value) throws -> R) rethrows -> R {
    try transform(&self._wrappedValue)
  }

  /// The underlying value referenced by the shared variable.
  ///
  /// This property provides primary access to the value's data. However, you don't access
  /// `wrappedValue` directly. Instead, you use the property variable created with the ``Shared``
  /// attribute. In the following example, the shared variable `topics` returns the value of
  /// `wrappedValue`:
  ///
  /// ```swift
  /// struct State {
  ///   @Shared var subscriptions: [Subscription]
  ///
  ///   var isSubscribed: Bool {
  ///     !subscriptions.isEmpty
  ///   }
  /// }
  /// ```
  public var wrappedValue: Value {
    get { _wrappedValue }
    @available(*, noasync, message: "Use '$shared.withLock' instead of mutating directly.")
    nonmutating set { _wrappedValue = newValue }
  }

  /// A projection of the shared value that returns a shared reference.
  ///
  /// Use the projected value to pass a shared value down to another feature. This is most
  /// commonly done to share a value from one feature to another:
  ///
  /// ```swift
  /// case .nextButtonTapped:
  ///   state.path.append(
  ///     PersonalInfoFeature(signUpData: state.$signUpData)
  ///   )
  /// ```
  ///
  /// Further you can use dot-chaining syntax to derive a smaller piece of shared state to hand
  /// to another feature:
  ///
  /// ```swift
  /// case .nextButtonTapped:
  ///   state.path.append(
  ///     PhoneNumberFeature(phoneNumber: state.$signUpData.phoneNumber)
  ///   )
  /// ```
  ///
  /// See <doc:SharingState#Deriving-shared-state> for more details.
  public var projectedValue: Self {
    get {
      reference.access()
      return self
    }
    set {
      reference.withMutation {
        self = newValue
      }
    }
  }

  #if canImport(Combine)
    /// Returns a publisher that emits events when the underlying value changes.
    ///
    /// Useful when a feature needs to execute logic when a shared reference is updated outside of
    /// the feature itself.
    ///
    /// ```swift
    /// case .onAppear:
    ///   return .run { [currentUser = state.$currentUser] send in
    ///     for await _ in currentUser.publisher.values {
    ///       await send(.currentUserUpdated)
    ///     }
    ///   }
    /// ```
    public var publisher: AnyPublisher<Value, Never> {
      func open<Root>(_ reference: some Reference<Root>) -> AnyPublisher<Value, Never> {
        reference.publisher
          .map { $0[keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)] }
          .eraseToAnyPublisher()
      }
      return open(self.reference)
    }
  #endif

  /// Returns a shared reference to the resulting value of a given key path.
  ///
  /// You don't call this subscript directly. Instead, Swift calls it for you when you access a
  /// property of the underlying value. In the following example, the property access
  /// `$signUpData.topics` returns the value of invoking this subscript with `\SignUpData.topics`:
  ///
  /// ```swift
  /// @Shared var signUpData: SignUpData
  ///
  /// $signUpData.topics  // Shared<Set<Topic>>
  /// ```
  ///
  /// - Parameter keyPath: A key path to a specific resulting value.
  /// - Returns: A new binding.
  public subscript<Member>(
    dynamicMember keyPath: WritableKeyPath<Value, Member>
  ) -> Shared<Member> {
    Shared<Member>(
      reference: self.reference,
      // NB: Can get rid of bitcast when this is fixed:
      //     https://github.com/swiftlang/swift/issues/75531
      keyPath: (self.keyPath as AnyKeyPath)
        .appending(path: keyPath)!
        .unsafeSendable()
    )
  }

  @_disfavoredOverload
  @available(
    *, deprecated, message: "Use 'Shared($value.optional)' to unwrap optional shared values"
  )
  public subscript<Member>(
    dynamicMember keyPath: WritableKeyPath<Value, Member?>
  ) -> Shared<Member>? {
    Shared<Member>(self[dynamicMember: keyPath])
  }

  public func assert(
    _ updateValueToExpectedResult: (inout Value) throws -> Void,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) rethrows where Value: Equatable {
    @Dependency(\.sharedChangeTrackers) var changeTrackers
    guard
      let changeTracker =
        changeTrackers
        .first(where: { $0.changes[ObjectIdentifier(self.reference)] != nil })
    else {
      reportIssue(
        "Expected changes, but none occurred.",
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return
    }
    try changeTracker.assert {
      guard var snapshot = self.snapshot, snapshot != self.currentValue else {
        reportIssue(
          "Expected changes, but none occurred.",
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
        return
      }
      try updateValueToExpectedResult(&snapshot)
      self.snapshot = snapshot
      // TODO: Finesse error more than `expectNoDifference`
      expectNoDifference(
        self.currentValue,
        self.snapshot,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      self.snapshot = nil
    }
  }

  fileprivate var _wrappedValue: Value {
    get {
      @Dependency(\.sharedChangeTracker) var changeTracker
      if changeTracker != nil {
        return self.snapshot ?? self.currentValue
      } else {
        return self.currentValue
      }
    }
    nonmutating set {
      @Dependency(\.sharedChangeTracker) var changeTracker
      if changeTracker != nil {
        self.snapshot = newValue
      } else {
        @Dependency(\.sharedChangeTrackers) var changeTrackers: Set<SharedChangeTracker>
        for changeTracker in changeTrackers {
          changeTracker.track(self.reference)
        }
        self.currentValue = newValue
      }
    }
  }

  private var currentValue: Value {
    get {
      func open<Root>(_ reference: some Reference<Root>) -> Value {
        reference.value[
          keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)
        ]
      }
      return open(self.reference)
    }
    nonmutating set {
      func open<Root>(_ reference: some Reference<Root>) {
        reference.value[
          keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
        ] = newValue
      }
      return open(self.reference)
    }
  }

  private var snapshot: Value? {
    get {
      func open<Root: Sendable>(_ reference: some Reference<Root>) -> Value? {
        @Dependency(\.sharedChangeTracker) var changeTracker
        return changeTracker?[reference]?.snapshot[
          keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
        ]
      }
      return open(self.reference)
    }
    nonmutating set {
      func open<Root: Sendable>(_ reference: some Reference<Root>) {
        @Dependency(\.sharedChangeTracker) var changeTracker
        guard let newValue else {
          changeTracker?[reference] = nil
          return
        }
        if changeTracker?[reference] == nil {
          changeTracker?[reference] = AnyChange(reference)
        }
        changeTracker?[reference]?.snapshot[
          keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
        ] = newValue
      }
      return open(self.reference)
    }
  }
}

extension Shared: Equatable where Value: Equatable {
  public static func == (lhs: Shared, rhs: Shared) -> Bool {
    @Dependency(\.sharedChangeTracker) var changeTracker
    if changeTracker != nil, lhs.reference === rhs.reference, lhs.keyPath == rhs.keyPath {
      if let lhsReference = lhs.reference as? any Equatable {
        func open<T: Equatable>(_ lhsReference: T) -> Bool {
          lhsReference == rhs.reference as? T
        }
        return open(lhsReference)
      }
      return lhs.snapshot ?? lhs.currentValue == rhs.currentValue
    } else {
      return lhs.wrappedValue == rhs.wrappedValue
    }
  }
}

extension Shared: Identifiable where Value: Identifiable {
  public var id: Value.ID {
    self.wrappedValue.id
  }
}

extension Shared: CustomDumpRepresentable {
  public var customDumpValue: Any {
    self.currentValue
  }
}

extension Shared: _CustomDiffObject {
  public var _customDiffValues: (Any, Any) {
    (self.snapshot ?? self.currentValue, self.currentValue)
  }

  public var _objectIdentifier: ObjectIdentifier {
    ObjectIdentifier(self.reference)
  }
}

extension Shared
where
  Value: _MutableIdentifiedCollection,
  Value.Element: Sendable
{
  /// Allows a `ForEach` view to transform a shared collection into shared elements.
  ///
  /// ```swift
  /// struct State {
  ///   @Shared(.fileStorage(.todos)) var todos: IdentifiedArrayOf<Todo> = []
  ///   // ...
  /// }
  ///
  /// // ...
  ///
  /// ForEach(store.$todos.elements) { $todo in
  ///   NavigationLink(
  ///     // $todo: Shared<Todo>
  ///     //  todo: Todo
  ///     state: Path.State.todo(TodoFeature.State(todo: $todo))
  ///   ) {
  ///     Text(todo.title)
  ///   }
  /// }
  /// ```
  ///
  /// > Warning: It is not appropriate to use this property outside of SwiftUI's `ForEach` view. If
  /// > you need to derive a shared element from a shared collection, use a stable lookup, instead,
  /// > like the `$array[id:]` subscript on `IdentifiedArray`.
  public var elements: some RandomAccessCollection<Shared<Value.Element>> {
    zip(self.wrappedValue.ids, self.wrappedValue).lazy.map { id, element in
      self[id: id, default: DefaultSubscript(element)]
    }
  }
}

@available(
  *,
  unavailable,
  message:
    "Derive shared elements from a stable subscript, like '$array[id:]' on 'IdentifiedArray', or pass '$array.elements' to a 'ForEach' view."
)
extension Shared: Collection, Sequence
where Value: MutableCollection & RandomAccessCollection, Value.Index: Hashable {
  public var startIndex: Value.Index {
    assertionFailure("Conformance of 'Shared<Value>' to 'Collection' is unavailable.")
    return self.wrappedValue.startIndex
  }
  public var endIndex: Value.Index {
    assertionFailure("Conformance of 'Shared<Value>' to 'Collection' is unavailable.")
    return self.wrappedValue.endIndex
  }
  public func index(after i: Value.Index) -> Value.Index {
    assertionFailure("Conformance of 'Shared<Value>' to 'Collection' is unavailable.")
    return self.wrappedValue.index(after: i)
  }
}

@available(
  *,
  unavailable,
  message:
    "Derive shared elements from a stable subscript, like '$array[id:]' on 'IdentifiedArray', or pass '$array.elements' to a 'ForEach' view."
)
extension Shared: MutableCollection
where Value: MutableCollection & RandomAccessCollection, Value.Index: Hashable {
  public subscript(position: Value.Index) -> Shared<Value.Element> {
    get {
      fatalError("Conformance of 'Shared<Value>' to 'MutableCollection' is unavailable.")
    }
    set {
      fatalError("Conformance of 'Shared<Value>' to 'MutableCollection' is unavailable.")
    }
  }
}

@available(
  *,
  unavailable,
  message:
    "Derive shared elements from a stable subscript, like '$array[id:]' on 'IdentifiedArray', or pass '$array.elements' to a 'ForEach' view."
)
extension Shared: BidirectionalCollection
where Value: MutableCollection & RandomAccessCollection, Value.Index: Hashable {
  public func index(before i: Value.Index) -> Value.Index {
    assertionFailure("Conformance of 'Shared<Value>' to 'BidirectionalCollection' is unavailable.")
    return self.wrappedValue.index(before: i)
  }
}

@available(
  *,
  unavailable,
  message:
    "Derive shared elements from a stable subscript, like '$array[id:]' on 'IdentifiedArray', or pass '$array.elements' to a 'ForEach' view."
)
extension Shared: RandomAccessCollection
where Value: MutableCollection & RandomAccessCollection, Value.Index: Hashable {
}

extension Shared {
  public subscript<Member>(
    dynamicMember keyPath: KeyPath<Value, Member>
  ) -> SharedReader<Member> {
    SharedReader<Member>(
      reference: self.reference,
      keyPath: (self.keyPath as AnyKeyPath).appending(path: keyPath)!.unsafeSendable()
    )
  }

  /// Constructs a read-only version of the shared value.
  public var reader: SharedReader<Value> {
    SharedReader(reference: self.reference, keyPath: self.keyPath)
  }

  @_disfavoredOverload
  @available(
    *, deprecated, message: "Use 'SharedReader($value.optional)' to unwrap optional shared values"
  )
  public subscript<Member>(
    dynamicMember keyPath: KeyPath<Value, Member?>
  ) -> SharedReader<Member>? {
    SharedReader(self[dynamicMember: keyPath])
  }
}
