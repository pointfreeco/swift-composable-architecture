@dynamicMemberLookup
@propertyWrapper
final class Ref<Value> {
  var wrappedValue: Value

  init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }

  var projectedValue: Ref {
    self
  }

  subscript<NewValue>(dynamicMember keyPath: KeyPath<Value, NewValue>) -> NewValue {
    self.wrappedValue[keyPath: keyPath]
  }

  subscript<NewValue>(
    dynamicMember keyPath: WritableKeyPath<Value, NewValue>
  ) -> NewValue {
    _read { yield self.wrappedValue[keyPath: keyPath] }
    _modify { yield &self.wrappedValue[keyPath: keyPath] }
  }
}
