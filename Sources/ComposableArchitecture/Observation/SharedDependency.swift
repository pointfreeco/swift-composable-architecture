extension DependencyValues {
  public subscript<Key: TestDependencyKey>(
    shared _: Key.Type,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Key.Value {
    get { self[Shared<Key>.self].wrappedValue }
    set { self[Shared<Key>.self] = Shared(newValue, fileID: fileID, line: line) }
  }
}

@propertyWrapper
public struct SharedDependency<Key: TestDependencyKey> where Key.Value == Key {
  private let dependency = Dependency(Shared<Key>.self)

  public var wrappedValue: Key.Value {
    get { dependency.wrappedValue.wrappedValue }
    set { dependency.wrappedValue.wrappedValue = newValue }
  }

  public var projectedValue: Shared<Key.Value> {
    dependency.wrappedValue
  }

  public init() {}
}

extension SharedDependency: Equatable where Key.Value: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.dependency.wrappedValue == rhs.dependency.wrappedValue
  }
}

extension SharedDependency: Hashable where Key.Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.wrappedValue)
  }
}

extension SharedDependency: CustomDumpRepresentable {
  public var customDumpValue: Any {
    self.dependency.wrappedValue
  }
}
