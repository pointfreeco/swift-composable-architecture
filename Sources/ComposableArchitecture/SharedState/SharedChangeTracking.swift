import CustomDump
import Dependencies

public func withSharedChangeTracking<T>(
  _ apply: () throws -> T
) rethrows -> T {
  try withDependencies {
    $0[SharedChangeTrackerKey.self] = $0[SharedChangeTrackerKey.self]?.copy()
      ?? SharedChangeTracker()
  } operation: {
    try apply()
  }
}

public func withSharedChangeTracking<T>(
  _ apply: () async throws -> T
) async rethrows -> T {
  try await withDependencies {
    $0[SharedChangeTrackerKey.self] = $0[SharedChangeTrackerKey.self]?.copy()
      ?? SharedChangeTracker()
  } operation: {
    try await apply()
  }
}

protocol Change<Value> {
  associatedtype Value
  var reference: any Reference<Value> { get }
  var snapshot: Value { get set }
}

extension Change {
  func assertUnchanged() {
    if let difference = diff(snapshot, self.reference.value, format: .proportional) {
      XCTFail(
        """
        Tracked changes to '\(self.reference.description)' but failed to assert: …

        \(difference.indent(by: 2))

        (Before: −, After: +)

        Call 'Shared<\(Value.self)>.assert' to exhaustively test these changes, or call \
        'skipChanges' to ignore them.
        """
      )
    }
  }
}

struct AnyChange<Value>: Change {
  let reference: any Reference<Value>
  var snapshot: Value

  init(_ reference: some Reference<Value>) {
    self.reference = reference
    self.snapshot = reference.value
  }
}

@_spi(Internals) public final class SharedChangeTracker {
  var changes: [ObjectIdentifier: Any] = [:]
  @_spi(Internals) public var isAsserting = false
  @_spi(Internals) public var hasChanges: Bool { !self.changes.isEmpty }
  @_spi(Internals) public init() {}
  @_spi(Internals) public func resetChanges() { self.changes.removeAll() }
  @_spi(Internals) public func assertUnchanged() {
    for change in self.changes.values {
      if let change = change as? any Change {
        change.assertUnchanged()
      }
    }
    self.changes.removeAll()
  }
  func track<Value>(_ reference: some Reference<Value>) {
    if !self.changes.keys.contains(ObjectIdentifier(reference)) {
      self.changes[ObjectIdentifier(reference)] = AnyChange(reference)
    }
  }
  subscript<Value>(_ reference: some Reference<Value>) -> AnyChange<Value>? {
    _read { yield self.changes[ObjectIdentifier(reference)] as? AnyChange<Value> }
    _modify {
      var change = self.changes[ObjectIdentifier(reference)] as? AnyChange<Value>
      yield &change
      self.changes[ObjectIdentifier(reference)] = change
    }
  }
  func copy() -> SharedChangeTracker {
    let changeTracker = SharedChangeTracker()
    changeTracker.changes = self.changes
    return changeTracker
  }
}

@_spi(Internals) public enum SharedChangeTrackerKey: DependencyKey {
  @_spi(Internals) public static var liveValue: SharedChangeTracker? { nil }
  @_spi(Internals) public static var testValue: SharedChangeTracker? { SharedChangeTracker() }
}
