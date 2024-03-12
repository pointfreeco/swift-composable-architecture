import CustomDump
import Foundation

#if canImport(Combine)
  import Combine
#endif

#if canImport(Perception)
  /// A property wrapper type that shares a value with multiple parts of an application.
  ///
  /// See the <doc:SharingState> article for more detailed information on how to use this property
  /// wrapper.
  @dynamicMemberLookup
  @propertyWrapper
  public struct Shared<Value> {
    fileprivate let reference: any Reference
    private let keyPath: AnyKeyPath

    init(reference: any Reference, keyPath: AnyKeyPath) {
      self.reference = reference
      self.keyPath = keyPath
    }

    init(reference: some Reference<Value>) {
      self.init(reference: reference, keyPath: \Value.self)
    }

    public init(projectedValue: Shared) {
      self = projectedValue
    }

    public var wrappedValue: Value {
      get {
        if SharedLocals.isProcessingChanges {
          return self.snapshot ?? self.currentValue
        } else {
          @Dependency(SharedChangeTracker.self) var sharedChangeTracker
          // NB: Take snapshots of objects when they are accessed since mutations cannot be detected.
          if Value.self is AnyObject.Type,
            sharedChangeTracker != nil,
            !SharedLocals.isProcessingChanges,
            self.snapshot == nil
          {
            self.reference.takeSnapshot()
          }
          return self.currentValue
        }
      }
      nonmutating set {
        @Dependency(SharedChangeTracker.self) var sharedChangeTracker
        if let sharedChangeTracker = sharedChangeTracker {
          if SharedLocals.isProcessingChanges {
            self.snapshot = newValue
          } else {
            if self.snapshot == nil {
              self.reference.takeSnapshot()
            }
            self.currentValue = newValue
            sharedChangeTracker.track(self)
          }
        } else {
          self.currentValue = newValue
          self.reference.clearSnapshot()
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
      get { self }
      set { self = newValue }
    }

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

    public func skipChanges(
      file: StaticString = #file,
      line: UInt = #line
    ) {
      guard self.snapshot != nil else {
        XCTFail("Expected changes, but none occurred.", file: file, line: line)
        return
      }
      self.snapshot = nil
    }

    #if canImport(Combine)
      public var publisher: AnyPublisher<Value, Never> {
        func open<R: Reference>(_ reference: R) -> AnyPublisher<Value, Never> {
          return reference.publisher
            .compactMap { $0[keyPath: self.keyPath] as? Value }
            .eraseToAnyPublisher()
        }
        return open(self.reference)
      }
    #endif

    private var currentValue: Value {
      get {
        func open<Root>(_ reference: some Reference<Root>) -> Value {
          reference.currentValue[
            keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)
          ]
        }
        return open(self.reference)
      }
      nonmutating set {
        func open<Root>(_ reference: some Reference<Root>) {
          reference.currentValue[
            keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
          ] = newValue
        }
        return open(self.reference)
      }
    }

    fileprivate var snapshot: Value? {
      get {
        func open<Root>(_ reference: some Reference<Root>) -> Value? {
          reference.snapshot?[keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)]
        }
        return open(self.reference)
      }
      nonmutating set {
        func open<Root>(_ reference: some Reference<Root>) {
          if reference.snapshot == nil {
            reference.takeSnapshot()
          }
          if let newValue {
            reference.snapshot?[
              keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
            ] = newValue
          } else {
            reference.snapshot = nil
          }
        }
        return open(self.reference)
      }
    }
  }

  extension Shared: @unchecked Sendable where Value: Sendable {}

  extension Shared: Equatable where Value: Equatable {
    public static func == (lhs: Shared, rhs: Shared) -> Bool {
      if SharedLocals.exhaustivity == .on, lhs.reference === rhs.reference {
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

  extension Shared: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.wrappedValue)
    }
  }

  extension Shared: Identifiable where Value: Identifiable {
    public var id: Value.ID {
      self.wrappedValue.id
    }
  }

  extension Shared: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
      do {
        self.init(try decoder.singleValueContainer().decode(Value.self))
      } catch {
        self.init(try .init(from: decoder))
      }
    }
  }

  extension Shared: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
      do {
        var container = encoder.singleValueContainer()
        try container.encode(self.wrappedValue)
      } catch {
        try self.wrappedValue.encode(to: encoder)
      }
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
    /// Derives a collection of shared elements from a shared collection of elements.
    ///
    /// This can be useful when used in conjunction with `ForEach` in order to derive a shared
    /// reference for each element of a collection:
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
    public var elements: some RandomAccessCollection<Shared<Value.Element>> {
      zip(self.wrappedValue.indices, self.wrappedValue).lazy.map { index, element in
        self[index, default: DefaultSubscript(element)]
      }
    }
  }
#endif

enum SharedLocals {
  @TaskLocal static var exhaustivity: Exhaustivity?
  static var isProcessingChanges: Bool { Self.exhaustivity != nil }
}

final class SharedChangeTracker {
  var hasChanges: Bool { !self.changes.isEmpty }
  private var changes: [ObjectIdentifier: any Reference] {
    _read {
      self.lock.lock()
      defer { self.lock.unlock() }
      yield self._changes
    }
    _modify {
      self.lock.lock()
      defer { self.lock.unlock() }
      yield &self._changes
    }
  }
  private let lock = NSRecursiveLock()
  private var _changes: [ObjectIdentifier: any Reference] = [:]

  #if canImport(Perception)
    func track<Value>(_ shared: Shared<Value>) {
      self.changes[ObjectIdentifier(shared.reference)] = shared.reference
    }
  #endif
  func clearChanges() {
    for change in self.changes.values {
      change.clearSnapshot()
    }
    self.changes.removeAll()
  }
  func assertUnchanged() {
    for change in self.changes.values {
      change.assertUnchanged()
    }
    self.changes.removeAll()
  }
}

extension SharedChangeTracker: DependencyKey {
  static let liveValue: SharedChangeTracker? = nil
  static let testValue: SharedChangeTracker? = nil
}

extension Optional {
  fileprivate subscript(default defaultSubscript: DefaultSubscript<Wrapped>) -> Wrapped {
    get { self ?? defaultSubscript.value }
    set {
      defaultSubscript.value = newValue
      if self != nil { self = newValue }
    }
  }
}

extension RandomAccessCollection where Self: MutableCollection {
  fileprivate subscript(
    position: Index, default defaultSubscript: DefaultSubscript<Element>
  ) -> Element {
    get { self.indices.contains(position) ? self[position] : defaultSubscript.value }
    set {
      defaultSubscript.value = newValue
      if self.indices.contains(position) { self[position] = newValue }
    }
  }
}

private final class DefaultSubscript<Value>: Hashable {
  var value: Value
  init(_ value: Value) {
    self.value = value
  }
  static func == (lhs: DefaultSubscript, rhs: DefaultSubscript) -> Bool {
    lhs === rhs
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
