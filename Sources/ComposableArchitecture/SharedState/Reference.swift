#if canImport(Combine)
  import Combine
#endif

protocol Reference<Value>: AnyObject, CustomStringConvertible {
  associatedtype Value
  var value: Value { get set }
  var persistence: Any? { get }

  #if canImport(Combine)
    var publisher: AnyPublisher<Value, Never> { get }
  #endif
}
