extension Shared {
  @_disfavoredOverload
  public init(
    wrappedValue value: Value,
    _ key: _InMemory<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(wrappedValue: value, key, fileID: fileID, line: line)
  }

  @_disfavoredOverload
  @available(
    *,
    deprecated,
    message: "Use '@Shared' with a value type or supported reference type"
  )
  public init(
    wrappedValue value: Value,
    _ key: _InMemory<Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Value: AnyObject {
    self.init(wrappedValue: value, key, fileID: fileID, line: line)
  }
}

extension Persistent {
  public static func inMemory<Value>(_ key: String) -> Self
  where Self == _InMemory<Value> {
    _InMemory(key: key)
  }
}

public struct _InMemory<Value>: Hashable, Persistent, Sendable {
  let key: String
  public func load() -> Value? { nil }
  public func save(_ value: Value) {}
}

extension _InMemory: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) {
    self.init(key: value)
  }
}
