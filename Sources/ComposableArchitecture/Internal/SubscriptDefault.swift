final class SubscriptDefault<Value> {
  var wrappedValue: Value

  init(_ wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }
}

extension SubscriptDefault: Hashable {
  static func == (lhs: SubscriptDefault<Value>, rhs: SubscriptDefault<Value>) -> Bool {
    true
  }

  func hash(into hasher: inout Hasher) {}
}

extension IdentifiedArray {
  subscript(id id: ID, default default: SubscriptDefault<Element>) -> Element {
    `default`.wrappedValue = self[id: id] ?? `default`.wrappedValue
    return `default`.wrappedValue
  }
}

extension Optional {
  subscript(default default: SubscriptDefault<Wrapped>) -> Wrapped! {
    `default`.wrappedValue = self ?? `default`.wrappedValue
    return `default`.wrappedValue
  }
}

extension StackState {
  subscript(id id: StackElementID, default default: SubscriptDefault<Element>) -> Element {
    `default`.wrappedValue = self[id: id] ?? `default`.wrappedValue
    return `default`.wrappedValue
  }
}
