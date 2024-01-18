#if canImport(Perception)
  import Foundation

  @dynamicMemberLookup
  @propertyWrapper
  public struct Shared<Value> {
    fileprivate let reference: any ReferenceProtocol
    private let keyPath: AnyKeyPath

    public init(_ value: Value, fileID: StaticString = #fileID, line: UInt = #line) {
      self.init(reference: Reference(value, fileID: fileID, line: line), keyPath: \Value.self)
    }

    public init(
      wrappedValue value: Value,
      _ persistence: some SharedPersistence<Value>,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) {
      self.init(
        reference: {
          @Dependency(\.sharedPersistentReferences) var references
          return references.withValue {
            if let reference = $0[persistence] {
              return reference
            } else {
              let reference = Reference(
                value,
                persistence: persistence,
                fileID: fileID,
                line: line
              )
              $0[persistence] = reference
              return reference
            }
          }
        }(),
        keyPath: \Value.self
      )
    }

    public init<Wrapped>(
      wrappedValue value: Value = nil,
      _ persistence: some SharedPersistence<Value>,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) where Value == Wrapped? {
      self.init(
        reference: {
          @Dependency(\.sharedPersistentReferences) var references
          return references.withValue {
            if let reference = $0[persistence] {
              return reference
            } else {
              let reference = Reference(
                value,
                persistence: persistence,
                fileID: fileID,
                line: line
              )
              $0[persistence] = reference
              return reference
            }
          }
        }(),
        keyPath: \Value.self
      )
    }

    private init(reference: any ReferenceProtocol, keyPath: AnyKeyPath) {
      self.reference = reference
      self.keyPath = keyPath
    }

    public var wrappedValue: Value {
      get {
        if SharedLocals.isAsserting {
          self.snapshot ?? self.currentValue
        } else {
          self.currentValue
        }
      }
      nonmutating set {
        @Dependency(\.sharedChangeTracker) var sharedChangeTracker
        if let sharedChangeTracker {
          if SharedLocals.isAsserting {
            self.snapshot = newValue
          } else {
            if self.snapshot == nil {
              self.snapshot = self.currentValue
            }
            self.currentValue = newValue
            sharedChangeTracker.track(self)
          }
        } else {
          self.currentValue = newValue
          self.snapshot = nil
        }
      }
    }

    public var projectedValue: Shared {
      get { self }
      set { self = newValue }
    }

    fileprivate var currentValue: Value {
      get {
        func open<Root>(_ reference: some ReferenceProtocol<Root>) -> Value {
          reference.currentValue[
            keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)
          ]
        }
        return open(self.reference)
      }
      nonmutating set {
        func open<Root>(_ reference: some ReferenceProtocol<Root>) {
          reference.currentValue[
            keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
          ] = newValue
        }
        return open(self.reference)
      }
    }

    fileprivate var snapshot: Value? {
      get {
        func open<Root>(_ reference: some ReferenceProtocol<Root>) -> Value? {
          reference.snapshot?[keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)]
        }
        return open(self.reference)
      }
      nonmutating set {
        func open<Root>(_ reference: some ReferenceProtocol<Root>) {
          // TODO: Instead, copy `currentValue` over to `snapshot` when `nil` before applying changes.
          if self.keyPath == \Root.self {
            reference.snapshot = newValue as! Root?
          } else if let newValue {
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
        // TODO: Can this crash?
        keyPath: self.keyPath.appending(
          path: keyPath.appending(path: \.[default: DefaultSubscript(initialValue)])
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
  }

  extension Shared: @unchecked Sendable where Value: Sendable {}

  // TODO: Can this just be `lhs.reference == rhs.reference`
  extension Shared: Equatable where Value: Equatable {
    public static func == (lhs: Shared, rhs: Shared) -> Bool {
      if SharedLocals.exhaustivity == .on, lhs.reference === rhs.reference {
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

  extension Shared: TestDependencyKey where Value: TestDependencyKey {
    public static var testValue: Shared<Value.Value> {
      withDependencies {
        $0[Value.self] = Value.testValue
      } operation: {
        @Dependency(Value.self) var testValue
        return Shared<Value.Value>(testValue)
      }
    }
  }

  extension Shared: DependencyKey where Value: DependencyKey {
    public static var liveValue: Shared<Value.Value> {
      Shared<Value.Value>(Value.liveValue)
    }
  }

  extension Shared: CustomDumpRepresentable {
    public var customDumpValue: Any {
      self.reference
    }
  }

  protocol ReferenceProtocol<Value>: AnyObject /* TODO: , Hashable? */ {
    associatedtype Value
    var currentValue: Value { get set }
    var snapshot: Value? { get set }
    func complete()
    func reset()
  }

  @Perceptible
  private final class Reference<Value>: ReferenceProtocol {
    var _currentValue: Value
    @PerceptionIgnored
    var _snapshot: Value?
    let lock = NSRecursiveLock()
    let _$perceptionRegistrar = PerceptionRegistrar(
      isPerceptionCheckingEnabled: _isPlatformPerceptionCheckingEnabled
    )
    let fileID: StaticString
    let line: UInt
    @PerceptionIgnored
    var persistence: (any SharedPersistence<Value>)?
    var currentValue: Value {
      get { self.lock.withLock { self._currentValue } }
      set {
        self.lock.withLock { self._currentValue = newValue }
        self.persistence?.save(newValue)
      }
    }
    var snapshot: Value? {
      get { self.lock.withLock { self._snapshot } }
      set { self.lock.withLock { self._snapshot = newValue } }
    }
    init(
      _ value: Value,
      fileID: StaticString,
      line: UInt
    ) {
      self._currentValue = value
      self.persistence = nil
      self.fileID = fileID
      self.line = line
    }
    init(
      _ value: Value,
      persistence: some SharedPersistence<Value>,
      fileID: StaticString,
      line: UInt
    ) {
      self._currentValue = persistence.load() ?? value
      self.persistence = persistence
      self.fileID = fileID
      self.line = line
      Task { @MainActor [weak self] in
        for try await value in persistence.updates {
          self?.currentValue = value
        }
      }
    }
    deinit {
      self.complete()
    }
    func complete() {
      if
        let snapshot = self.snapshot,
        let difference = diff(snapshot, self.currentValue, format: .proportional)
      {
        XCTFail(
          """
          Tracked changes to 'Shared<\(Value.self)>@\(self.fileID):\(self.line)' but failed to \
          assert: …

          \(difference.indent(by: 2))

          (Before: −, After: +)

          Call 'Shared<\(Value.self)>.assert' to exhaustively test these changes, or call \
          'skipChanges' to ignore them.
          """
        )
      }
    }
    func reset() {
      self.snapshot = nil
    }
  }

  extension Reference: Equatable where Value: Equatable {
    static func == (lhs: Reference, rhs: Reference) -> Bool {
      if SharedLocals.exhaustivity == .on, lhs === rhs {
        return lhs.snapshot ?? lhs.currentValue == rhs.currentValue
      } else {
        return lhs.currentValue == rhs.currentValue
      }
    }
  }

  extension Reference: CustomDumpRepresentable {
    public var customDumpValue: Any {
      self.currentValue
    }
  }

  extension Reference: _CustomDiffObject {
    public var _customDiffValues: (Any, Any) {
      (self.snapshot ?? self.currentValue, self.currentValue)
    }
  }

  enum SharedLocals {
    @TaskLocal static var exhaustivity: Exhaustivity?
    static var isAsserting: Bool { Self.exhaustivity != nil }
  }

  final class SharedChangeTracker: @unchecked Sendable {
    private struct Value {
      let complete: () -> Void
      let reset: () -> Void
    }

    private var changed = LockIsolated<[ObjectIdentifier: Value]>([:])
    var hasChanges: Bool { !self.changed.value.isEmpty }
    func track<T>(_ shared: Shared<T>) {
      let reference = shared.reference
      self.changed.withValue {
        _ = $0[ObjectIdentifier(reference)] = Value(
          complete: { [weak reference] in
            reference?.complete()
          },
          reset: { [weak reference] in
            reference?.reset()
          }
        )
      }
    }
    func complete() {
      self.changed.withValue {
        for value in $0.values {
          value.complete()
          value.reset()
        }
        $0.removeAll()
      }
    }
    func reset() {
      self.changed.withValue {
        for value in $0.values {
          value.reset()
        }
        $0.removeAll()
      }
    }
  }

  struct SharedChangeTrackerKey: DependencyKey {
    static let liveValue: SharedChangeTracker? = nil
    static let testValue: SharedChangeTracker? = nil
  }

  extension DependencyValues {
    var sharedChangeTracker: SharedChangeTracker? {
      get { self[SharedChangeTrackerKey.self] }
      set { self[SharedChangeTrackerKey.self] = newValue }
    }
  }

  enum SharedPersistentReferencesKey: DependencyKey {
    static let liveValue = LockIsolated<[AnyHashable: any ReferenceProtocol]>([:])
    static let testValue = LockIsolated<[AnyHashable: any ReferenceProtocol]>([:])
  }

  extension DependencyValues {
    var sharedPersistentReferences: LockIsolated<[AnyHashable: any ReferenceProtocol]> {
      get { self[SharedPersistentReferencesKey.self] }
      set { self[SharedPersistentReferencesKey.self] = newValue }
    }
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

  fileprivate final class DefaultSubscript<Value>: Hashable {
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
#endif
