@dynamicMemberLookup
@propertyWrapper
public struct SharedReader<Value> {
  @Shared var value: Value
  public var wrappedValue: Value {
    self.value
  }

  init(shared: Shared<Value>) {
    self._value = shared
  }

  public init(projectedValue: Self) {
    self = projectedValue
  }

  public subscript<Member>(
    dynamicMember keyPath: WritableKeyPath<Value, Member>
  ) -> SharedReader<Member> {
    SharedReader<Member>(shared: self.$value[dynamicMember: keyPath])
  }

  public subscript<Member>(
    dynamicMember keyPath: WritableKeyPath<Value, Member?>
  ) -> SharedReader<Member>? {
    self.$value[dynamicMember: keyPath].map(SharedReader<Member>.init(shared:))
  }
}

extension Shared {
  public var reader: SharedReader<Value> {
    SharedReader(shared: self)
  }
}

extension SharedReader: Equatable where Value: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.$value == rhs.$value
  }
}
