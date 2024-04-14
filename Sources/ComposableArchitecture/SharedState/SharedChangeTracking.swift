import CustomDump
import Dependencies

func withSharedChangeTracking<T>(
  _ apply: (SharedChangeTracker) throws -> T
) rethrows -> T {
  let changeTracker = SharedChangeTracker()
  return try changeTracker.track {
    try apply(changeTracker)
  }
}

func withSharedChangeTracking<T>(
  _ apply: (SharedChangeTracker) async throws -> T
) async rethrows -> T {
  let changeTracker = SharedChangeTracker()
  return try await changeTracker.track {
    try await apply(changeTracker)
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

final class SharedChangeTracker {
  var changes: [ObjectIdentifier: Any] = [:]
  var hasChanges: Bool { !self.changes.isEmpty }
  init() {}
  func resetChanges() { self.changes.removeAll() }
  func assertUnchanged() {
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
  func track<R>(_ operation: () throws -> R) rethrows -> R {
    DependencyValues._current[SharedChangeTrackersKey.self].withValue {
      _ = $0.insert(self)
    }
    defer {
      DependencyValues._current[SharedChangeTrackersKey.self].withValue {
        _ = $0.remove(self)
      }
    }
    return try operation()
  }
  func track<R>(_ operation: () async throws -> R) async rethrows -> R {
    DependencyValues._current[SharedChangeTrackersKey.self].withValue {
      _ = $0.insert(self)
    }
    defer {
      DependencyValues._current[SharedChangeTrackersKey.self].withValue {
        _ = $0.remove(self)
      }
    }
    return try await operation()
  }
  func assert<R>(_ operation: () throws -> R) rethrows -> R {
    try withDependencies {
      $0[SharedChangeTrackerKey.self] = self
    } operation: {
      try operation()
    }
  }
}

extension SharedChangeTracker: Hashable {
  static func == (lhs: SharedChangeTracker, rhs: SharedChangeTracker) -> Bool {
    lhs === rhs
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

enum SharedChangeTrackersKey: DependencyKey {
  static var liveValue: LockIsolated<Set<SharedChangeTracker>> { LockIsolated([]) }
  static var testValue: LockIsolated<Set<SharedChangeTracker>> {
    LockIsolated([SharedChangeTracker()])
  }
}

enum SharedChangeTrackerKey: DependencyKey {
  static var liveValue: SharedChangeTracker? { nil }
  static var testValue: SharedChangeTracker? { nil }
}
