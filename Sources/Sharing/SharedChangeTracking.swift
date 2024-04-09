public func withSharedChangeTracking<T>(
  _ apply: () throws -> T
) rethrows -> T {
  let changeTracker = SharedLocals.changeTracker?.copy() ?? SharedChangeTracker()
  return try SharedLocals.$changeTracker.withValue(changeTracker) {
    try apply()
  }
}

public func withSharedChangeTracking<T>(
  _ apply: () async throws -> T
) async rethrows -> T {
  let changeTracker = SharedLocals.changeTracker?.copy() ?? SharedChangeTracker()
  return try await SharedLocals.$changeTracker.withValue(changeTracker) {
    try await apply()
  }
}

struct Change<Value> {
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
  @_spi(Internals) public func resetChanges() { self.changes.removeAll() }
  func track<Value>(_ reference: some Reference<Value>) {
    if !self.changes.keys.contains(ObjectIdentifier(reference)) {
      self.changes[ObjectIdentifier(reference)] = Change(reference)
    }
  }
  subscript<Value>(_ reference: some Reference<Value>) -> Change<Value>? {
    _read { yield self.changes[ObjectIdentifier(reference)] as? Change<Value> }
    _modify {
      var change = self.changes[ObjectIdentifier(reference)] as? Change<Value>
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
