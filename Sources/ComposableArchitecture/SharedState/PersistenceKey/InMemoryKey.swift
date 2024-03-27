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
    public static func inMemory<Value>(_ key: String) -> Self
    where Self == InMemoryKey<Value> {
      InMemoryKey(key)
    }
  }

  /// A type defining an in-memory persistence strategy
  ///
  /// See ``PersistenceKey/inMemory(_:)`` to create values of this type.
  public struct InMemoryKey<Value>: Hashable, PersistenceKey, Sendable {
    let key: String
    public init(_ key: String) {
      self.key = key
    }
    public func load(initialValue: Value?) -> Value? { initialValue }
    public func save(_ value: Value) {}
  }
#endif
