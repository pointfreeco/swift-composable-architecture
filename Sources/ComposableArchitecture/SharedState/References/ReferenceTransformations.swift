#if canImport(Combine)
  import Combine
#endif

final class _ReferenceFromOptional<Base: Reference<Value?>, Value>: Reference, Sendable {
  let cachedValue: LockIsolated<Value>
  let base: Base
  init(initialValue: Value, base: Base) {
    self.cachedValue = LockIsolated(initialValue)
    self.base = base
  }
  var id: ReferenceIdentifier {
    base.id
  }
  var value: Value {
    if let value = base.value {
      cachedValue.setValue(value)
      return value
    }
    return cachedValue.value
  }
  static func == (lhs: _ReferenceFromOptional, rhs: _ReferenceFromOptional) -> Bool {
    lhs.base == rhs.base
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(base)
  }

  func touch() { base.touch() }
  var description: String { base.description }
  #if canImport(Combine)
    var publisher: any Publisher<Value, Never> {
      func open(_ publisher: some Publisher<Value?, Never>) -> some Publisher<Value, Never> {
        publisher.compactMap { $0 }
      }
      return open(base.publisher)
    }
  #endif
}

extension _ReferenceFromOptional: MutableReference where Base: MutableReference {
  var value: Value {
    get {
      if let value = base.value {
        cachedValue.setValue(value)
        return value
      }
      return cachedValue.value
    }
    set {
      cachedValue.setValue(newValue)
      if base.value != nil {
        base.value = newValue
      }
    }
  }
  var snapshot: Value? {
    get { base.snapshot ?? nil }
    set { base.snapshot? = newValue }
  }
}

final class _ReferenceAppendKeyPath<
  Base: Reference, Value: Sendable, Path: KeyPath<Base.Value, Value> & Sendable
>: Reference, Sendable {
  let base: Base
  let keyPath: Path
  init(base: Base, keyPath: Path) {
    self.base = base
    self.keyPath = keyPath
  }
  var id: ReferenceIdentifier {
    base.id
  }
  var value: Value {
    base.value[keyPath: keyPath]
  }
  static func == (
    lhs: _ReferenceAppendKeyPath, rhs: _ReferenceAppendKeyPath
  ) -> Bool {
    lhs.base == rhs.base && lhs.keyPath == rhs.keyPath
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(base)
    hasher.combine(keyPath)
  }

  func touch() { base.touch() }
  var description: String { base.description }
  #if canImport(Combine)
    var publisher: any Publisher<Value, Never> {
      func open(_ publisher: some Publisher<Base.Value, Never>) -> any Publisher<Value, Never> {
        publisher.map(keyPath)
      }
      return open(base.publisher)
    }
  #endif
}

extension _ReferenceAppendKeyPath: MutableReference
where Base: MutableReference, Path: WritableKeyPath<Base.Value, Value> {
  var value: Value {
    get { base.value[keyPath: keyPath] }
    set { base.value[keyPath: keyPath] = newValue }
  }
  var snapshot: Value? {
    get { base.snapshot?[keyPath: keyPath] }
    set {
      if let newValue {
        base.snapshot?[keyPath: keyPath as WritableKeyPath<Base.Value, Value>] = newValue
      }
    }
  }
}
