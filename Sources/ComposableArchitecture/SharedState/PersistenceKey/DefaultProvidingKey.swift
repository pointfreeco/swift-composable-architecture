#if canImport(Perception)
  extension PersistenceKey {
    /// Creates a persistence key for sharing data in-memory for the lifetime of an application.
    ///
    /// For example, one could initialize a key with the date and time at which the application was
    /// most recently launched, and access this date from anywhere using the ``Shared`` property
    /// wrapper:
    ///
    /// ```swift
    /// @Shared(.inMemory("appLaunchedAt")) var appLaunchedAt = Date()
    /// ```
    ///
    /// - Parameter key: A string key identifying a value to share in memory.
    /// - Returns: An in-memory persistence key.
      public static func inMemory<Value>(_ key: String, defaultValue: Value) -> Self
    where Self == DefaultProvidingKey<InMemoryKey<Value>> {
      DefaultProvidingKey(.init(key), defaultValue: defaultValue)
    }
  }

  /// A decorator around an in-memory persistence strategy that provides a built-in default value.
  ///
  /// See ``PersistenceKey/inMemory(_:)`` to create values of this type.
public struct DefaultProvidingKey<UnderlyingKey: PersistenceKey>: Hashable, PersistenceKey, Sendable
  where UnderlyingKey: Hashable & Sendable, UnderlyingKey.Value: Hashable & Sendable {
    let key: UnderlyingKey
    let defaultValue: UnderlyingKey.Value
    init(_ key: UnderlyingKey, defaultValue: UnderlyingKey.Value) {
      self.key = key
      self.defaultValue = defaultValue
    }
    public func load(initialValue: UnderlyingKey.Value?) -> UnderlyingKey.Value? {
      self.key.load(initialValue: initialValue)
    }
    public func save(_ value: Value) {
      self.key.save(value)
    }
  }
#endif
