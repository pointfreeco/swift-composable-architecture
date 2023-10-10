import Observation

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Store: Observable where State: ObservableState {
  public var state: State {
    get {
      self._$observationRegistrar.access(self, keyPath: \.state)
      return self.stateSubject.value
    }
    set {
      if self.stateSubject.value._$id != newValue._$id {
        self._$observationRegistrar.withMutation(of: self, keyPath: \.state) {
          self.stateSubject.value = newValue
        }
      } else {
        self.stateSubject.value = newValue
      }
    }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}
