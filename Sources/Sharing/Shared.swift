import CustomDump
import Dependencies
import XCTestDynamicOverlay

#if canImport(Combine)
  import Combine
#endif

@dynamicMemberLookup
@propertyWrapper
public struct Shared<Value> {
  private let reference: any Reference
  private let keyPath: AnyKeyPath

  public var wrappedValue: Value {
    get {
      @Dependency(SharedChangeTrackerKey.self) var changeTracker
      if changeTracker?.isAsserting == true {
        return self.snapshot ?? self.currentValue
      } else {
        return self.currentValue
      }
    }
    nonmutating set {
      @Dependency(SharedChangeTrackerKey.self) var changeTracker
      if changeTracker?.isAsserting == true {
        self.snapshot = newValue
      } else {
        changeTracker?.track(self.reference)
        self.currentValue = newValue
      }
    }
  }

  public var projectedValue: Shared {
    get { self }
    set { self = newValue }
  }

  #if canImport(Combine)
    public var publisher: AnyPublisher<Value, Never> {
      func open<Root>(_ reference: some Reference<Root>) -> AnyPublisher<Value, Never> {
        reference.publisher
          .map { $0[keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)] }
          .eraseToAnyPublisher()
      }
      return open(self.reference)
    }
  #endif

  init(reference: any Reference, keyPath: AnyKeyPath) {
    self.reference = reference
    self.keyPath = keyPath
  }

  public init(_ value: Value, fileID: StaticString = #fileID, line: UInt = #line) {
    self.init(
      reference: ValueReference(initialValue: value, fileID: fileID, line: line),
      keyPath: \Value.self
    )
  }

  public init(projectedValue: Shared) {
    self = projectedValue
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
    @Dependency(SharedChangeTrackerKey.self) var changeTracker
    guard let changeTracker
    else {
      XCTFail(
        "Use 'withSharedChangeTracking' to track changes to assert against.",
        file: file,
        line: line
      )
      return
    }
    let wasAsserting = changeTracker.isAsserting
    changeTracker.isAsserting = true
    defer { changeTracker.isAsserting = wasAsserting }
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
        @Dependency(SharedChangeTrackerKey.self) var changeTracker
        return changeTracker?[reference]?.snapshot[
          keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
        ]
      }
      return open(self.reference)
    }
    nonmutating set {
      func open<Root>(_ reference: some Reference<Root>) {
        @Dependency(SharedChangeTrackerKey.self) var changeTracker
        guard let newValue else {
          changeTracker?[reference] = nil
          return
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
    @Dependency(SharedChangeTrackerKey.self) var changeTracker
    if changeTracker?.isAsserting == true, lhs.reference === rhs.reference {
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

extension Optional {
  fileprivate subscript(default defaultSubscript: DefaultSubscript<Wrapped>) -> Wrapped {
    get { self ?? defaultSubscript.value }
    set {
      defaultSubscript.value = newValue
      if self != nil { self = newValue }
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
