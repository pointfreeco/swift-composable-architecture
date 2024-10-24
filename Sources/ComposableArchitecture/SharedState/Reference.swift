#if canImport(Combine)
  import Combine
#endif

public struct ReferenceIdentifier: Hashable, Sendable {
  let rawValue: ObjectIdentifier
}

protocol Reference<Value>: AnyObject, CustomStringConvertible, Sendable, Hashable {
  associatedtype Value: Sendable
  var value: Value { get }
  var id: ReferenceIdentifier { get }
  func touch()
  #if canImport(Combine)
    var publisher: any Publisher<Value, Never> { get }
  #endif
}

protocol MutableReference<Value>: Reference {
  var value: Value { get set }
  var snapshot: Value? { get set }
}

extension MutableReference {
  func touch() {
    value = value
  }
}

extension Reference {
  var valueType: Any.Type {
    Value.self
  }
}

final class AnyMutableReference<Value: Sendable>: MutableReference {
  let base: any MutableReference<Value>

  init(_ base: any MutableReference<Value>) {
    self.base = base
  }

  var id: ReferenceIdentifier {
    base.id
  }
  var value: Value {
    get { base.value }
    set { base.value = newValue }
  }
  var snapshot: Value? {
    get { base.snapshot }
    set { base.snapshot = newValue }
  }
  var description: String { base.description }
  var publisher: any Publisher<Value, Never> { base.publisher }

  static func == (lhs: AnyMutableReference, rhs: AnyMutableReference) -> Bool {
    func open<T: MutableReference<Value>>(_ lhs: T) -> Bool {
      lhs == rhs as? T
    }
    return open(lhs.base)
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(base)
  }
}
