import Dependencies
import Foundation

extension PersistenceReaderKey {
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
  /// - Parameter key: A string key identifying a value to share in memory.
  /// - Returns: A persistence key.
  public static func appStorage<Value>(
    _ keyPath: ReferenceWritableKeyPath<UserDefaults, Value>
  ) -> Self where Self == AppStorageKeyPathKey<Value> {
    AppStorageKeyPathKey(keyPath)
  }
}

/// A type defining a user defaults persistence strategy via key path.
///
/// See ``PersistenceReaderKey/appStorage(_:)-5jsie`` to create values of this type.
public struct AppStorageKeyPathKey<Value> {
  private let keyPath: ReferenceWritableKeyPath<UserDefaults, Value>
  private let store: UserDefaults

  public init(_ keyPath: ReferenceWritableKeyPath<UserDefaults, Value>) {
    @Dependency(\.defaultAppStorage) var store
    self.keyPath = keyPath
    self.store = store
  }
}

extension AppStorageKeyPathKey: PersistenceKey {
  public func load(initialValue _: Value?) -> Value? {
    self.store[keyPath: self.keyPath]
  }

  public func save(_ newValue: Value) {
    SharedAppStorageLocals.$isSetting.withValue(true) {
      self.store[keyPath: self.keyPath] = newValue
    }
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @Sendable @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    let observer = self.store.observe(self.keyPath, options: .new) { _, change in
      guard
        !SharedAppStorageLocals.isSetting
      else { return }
      didSet(change.newValue ?? initialValue)
    }
    return Shared.Subscription {
      observer.invalidate()
    }
  }

  private class Observer: NSObject {
    let didChange: (Value?) -> Void
    init(didChange: @escaping (Value?) -> Void) {
      self.didChange = didChange
      super.init()
    }
    override func observeValue(
      forKeyPath keyPath: String?,
      of object: Any?,
      change: [NSKeyValueChangeKey: Any]?,
      context: UnsafeMutableRawPointer?
    ) {
      self.didChange(change?[.newKey] as? Value)
    }
  }
}

// NB: This is mainly used for tests, where observer notifications can bleed across cases.
private enum SharedAppStorageLocals {
  @TaskLocal static var isSetting = false
}
