import Combine

final class NonPersistedReference<Value>: Reference, @unchecked Sendable {
  var value: Value {
    get { self._value.withValue { $0 } }
    set { self._value.withValue { $0 = newValue } }
  }
  var _value: LockIsolated<Value>
#if canImport(Perception)
  private let _$perceptionRegistrar = PerceptionRegistrar(
    isPerceptionCheckingEnabled: _isStorePerceptionCheckingEnabled
  )
#endif
  init(
    initialValue: Value
  ) {
    self._value = LockIsolated(initialValue)
  }
  var publisher: AnyPublisher<Value, Never> = Empty().eraseToAnyPublisher()
  func access() {
#if canImport(Perception)
    _$perceptionRegistrar.access(self, keyPath: \.value)
#endif
  }
  func withMutation<T>(_ mutation: () throws -> T) rethrows -> T {
#if canImport(Perception)
    self._$perceptionRegistrar.willSet(self, keyPath: \.value)
    defer { self._$perceptionRegistrar.didSet(self, keyPath: \.value) }
#endif
    return try mutation()
  }
  var description: String {
    "Shared<\(Value.self)>"//@\(self.fileID):\(self.line)"
  }
}

#if canImport(Observation)
extension NonPersistedReference: Observable {}
#endif
#if canImport(Perception)
extension NonPersistedReference: Perceptible {}
#endif

