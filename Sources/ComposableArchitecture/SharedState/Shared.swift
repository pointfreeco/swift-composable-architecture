import CustomDump
import Dependencies
import XCTestDynamicOverlay

#if canImport(Combine)
  import Combine
#endif

/// A property wrapper type that shares a value with multiple parts of an application.
///
/// See the <doc:SharingState> article for more detailed information on how to use this property
/// wrapper.
@dynamicMemberLookup
@propertyWrapper
public struct Shared<Value> {
  private let reference: any Reference
  private let keyPath: AnyKeyPath

  init(reference: any Reference, keyPath: AnyKeyPath) {
    self.reference = reference
    self.keyPath = keyPath
  }

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

  public init(projectedValue: Shared) {
    self = projectedValue
  }

  public init?(_ base: Shared<Value?>) {
    guard let shared = base[dynamicMember: \.self] else { return nil }
    self = shared
  }

  public var wrappedValue: Value {
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
    // TODO: Should this be wrapped in a type we own instead of `AnyPublisher`?
    public var publisher: AnyPublisher<Value, Never> {
      func open<Root>(_ reference: some Reference<Root>) -> AnyPublisher<Value, Never> {
        reference.publisher
          .map { $0[keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)] }
          .eraseToAnyPublisher()
      }
      return open(self.reference)
    }
  #endif

  public subscript<Member>(
    dynamicMember keyPath: WritableKeyPath<Value, Member>
  ) -> Shared<Member> {
    Shared<Member>(reference: self.reference, keyPath: self.keyPath.appending(path: keyPath)!)
  }

  public subscript<Member>(
    dynamicMember keyPath: WritableKeyPath<Value, Member?>
  ) -> Shared<Member>? {
    guard let initialValue = self.wrappedValue[keyPath: keyPath]
    else { return nil }
    return Shared<Member>(
      reference: self.reference,
      keyPath: self.keyPath.appending(
        path: keyPath.appending(path: \.[default:DefaultSubscript(initialValue)])
      )!
    )
  }

  public func assert(
    _ updateValueToExpectedResult: (inout Value) throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
  ) rethrows where Value: Equatable {
    @Dependency(\.sharedChangeTrackers) var changeTrackers
    guard
      let changeTracker =
        changeTrackers
        .first(where: { $0.changes[ObjectIdentifier(self.reference)] != nil })
    else {
      XCTFail("Expected changes, but none occurred.", file: file, line: line)
      return
    }
    try changeTracker.assert {
      guard var snapshot = self.snapshot, snapshot != self.currentValue else {
        XCTFail("Expected changes, but none occurred.", file: file, line: line)
        return
      }
      try updateValueToExpectedResult(&snapshot)
      self.snapshot = snapshot
      // TODO: Finesse error more than `XCTAssertNoDifference`
      XCTAssertNoDifference(self.currentValue, self.snapshot, file: file, line: line)
      self.snapshot = nil
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
      func open<Root>(_ reference: some Reference<Root>) -> Value? {
        @Dependency(\.sharedChangeTracker) var changeTracker
        return changeTracker?[reference]?.snapshot[
          keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
        ]
      }
      return open(self.reference)
    }
    nonmutating set {
      func open<Root>(_ reference: some Reference<Root>) {
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

extension Shared: @unchecked Sendable where Value: Sendable {}

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
where Value: RandomAccessCollection & MutableCollection, Value.Index: Hashable & Sendable {
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
    zip(self.wrappedValue.indices, self.wrappedValue).lazy.map { index, element in
      self[index, default: DefaultSubscript(element)]
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
      assertionFailure("Conformance of 'Shared<Value>' to 'MutableCollection' is unavailable.")
      return self[position, default: DefaultSubscript(self.wrappedValue[position])]
    }
    set {
      self.wrappedValue[position] = newValue.wrappedValue
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
      keyPath: self.keyPath.appending(path: keyPath)!
    )
  }

  public var reader: SharedReader<Value> {
    SharedReader(reference: self.reference, keyPath: self.keyPath)
  }

  public subscript<Member>(
    dynamicMember keyPath: KeyPath<Value, Member?>
  ) -> SharedReader<Member>? {
    guard let initialValue = self.wrappedValue[keyPath: keyPath]
    else { return nil }
    return SharedReader<Member>(
      reference: self.reference,
      keyPath: self.keyPath.appending(
        path: keyPath.appending(path: \.[default:DefaultSubscript(initialValue)])
      )!
    )
  }
}
