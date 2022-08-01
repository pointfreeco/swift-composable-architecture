public struct DependencyValues {
  @TaskLocal public static var current = Self()

  private var storage: [ObjectIdentifier: Any] = [:]

  public init() {}

  public init(isTesting: Bool) {
    self.isTesting = isTesting
  }

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get {
      guard let dependency = self.storage[ObjectIdentifier(key)] as? Key.Value
      else {
        let isTesting = self.storage[ObjectIdentifier(IsTestingKey.self)] as? Bool ?? false
        guard !isTesting else { return Key.testValue }
        return _liveValue(Key.self) as? Key.Value ?? Key.testValue
      }
      return dependency
    }
    set {
      self.storage[ObjectIdentifier(key)] = newValue
    }
  }
}

// TODO: Why is this needed?
#if compiler(<5.7)
  extension DependencyValues: @unchecked Sendable {}
#endif

extension DependencyValues {
  public var isTesting: Bool {
    _read { yield self[IsTestingKey.self] }
    _modify { yield &self[IsTestingKey.self] }
  }

  private enum IsTestingKey: LiveDependencyKey {
    static let liveValue = false
    static let testValue = true
  }
}
