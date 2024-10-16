#if canImport(Combine)
  import Combine
#endif

protocol Reference<Value>: AnyObject, CustomStringConvertible, Sendable {
  associatedtype Value: Sendable
  var value: Value { get set }

  #if canImport(Combine)
    var publisher: AnyPublisher<Value, Never> { get }
  #endif
}

extension Reference {
  func touch() {
    value = value
  }
}

extension Reference {
  var valueType: Any.Type {
    Value.self
  }
}
