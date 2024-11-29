import Dependencies
import Foundation

// TODO: Deprecate? Soft-deprecate?

extension SharedReaderKey {
  /// Creates a persistence key for sharing data in user defaults given a key path.
  ///
  /// For example, one could initialize a key with the date and time at which the application was
  /// most recently launched, and access this date from anywhere using the ``Shared`` property
  /// wrapper:
  ///
  /// ```swift
  /// @Shared(.appStorage(\.appLaunchedAt)) var appLaunchedAt = Date()
  /// ```
  ///
  /// - Parameter keyPath: A string key identifying a value to share in memory.
  /// - Returns: A persistence key.
  public static func appStorage<Value>(
    _ keyPath: _SendableReferenceWritableKeyPath<UserDefaults, Value>
  ) -> Self where Self == AppStorageKeyPathKey<Value> {
    AppStorageKeyPathKey(keyPath)
  }
}

/// A type defining a user defaults persistence strategy via key path.
///
/// See ``PersistenceReaderKey/appStorage(_:)-69h4r`` to create values of this type.
public struct AppStorageKeyPathKey<Value: Sendable>: Sendable {
  private let keyPath: _SendableReferenceWritableKeyPath<UserDefaults, Value>
  private let store: UncheckedSendable<UserDefaults>

  public init(_ keyPath: _SendableReferenceWritableKeyPath<UserDefaults, Value>) {
    @Dependency(\.defaultAppStorage) var store
    self.keyPath = keyPath
    self.store = UncheckedSendable(store)
  }
}

extension AppStorageKeyPathKey: SharedKey, Hashable {
  public func load(initialValue _: Value?) -> Value? {
    self.store.wrappedValue[keyPath: self.keyPath]
  }

  public func save(_ newValue: Value, immediately: Bool) {
    SharedAppStorageLocals.$isSetting.withValue(true) {
      self.store.wrappedValue[keyPath: self.keyPath] = newValue
    }
  }

  public func subscribe(
    initialValue: Value?,
    didSet receiveValue: @escaping @Sendable (_ newValue: Value?) -> Void
  ) -> SharedSubscription {
    let observer = self.store.wrappedValue.observe(self.keyPath, options: .new) { _, change in
      guard
        !SharedAppStorageLocals.isSetting
      else { return }
      receiveValue(change.newValue ?? initialValue)
    }
    return SharedSubscription {
      observer.invalidate()
    }
  }
}

// NB: This is mainly used for tests, where observer notifications can bleed across cases.
private enum SharedAppStorageLocals {
  @TaskLocal static var isSetting = false
}
