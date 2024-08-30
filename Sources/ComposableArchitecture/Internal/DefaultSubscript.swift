final class DefaultSubscript<Value: Sendable>: Hashable, Sendable {
  let wrappedValue: LockIsolated<Value>
  init(_ value: Value) {
    self.wrappedValue = LockIsolated(value)
  }
  static func == (lhs: DefaultSubscript, rhs: DefaultSubscript) -> Bool {
    lhs === rhs
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

extension Optional where Wrapped: Sendable {
  subscript(default defaultSubscript: DefaultSubscript<Wrapped>) -> Wrapped {
    get { self ?? defaultSubscript.wrappedValue.value }
    set {
      defaultSubscript.wrappedValue.withValue { $0 = newValue }
      if self != nil { self = newValue }
    }
  }
}

extension RandomAccessCollection where Self: MutableCollection, Element: Sendable {
  subscript(
    position: Index,
    default defaultSubscript: DefaultSubscript<Element>
  ) -> Element {
    get { self.indices.contains(position) ? self[position] : defaultSubscript.wrappedValue.value }
    set {
      defaultSubscript.wrappedValue.withValue { $0 = newValue }
      if self.indices.contains(position) { self[position] = newValue }
    }
  }
}

extension _MutableIdentifiedCollection where Element: Sendable {
  subscript(
    id id: ID,
    default defaultSubscript: DefaultSubscript<Element>
  ) -> Element {
    get { self[id: id] ?? defaultSubscript.wrappedValue.value }
    set {
      defaultSubscript.wrappedValue.withValue { $0 = newValue }
      self[id: id] = newValue
    }
  }
}
