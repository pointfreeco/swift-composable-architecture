import Observation

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Store: Observable {
  // TODO: Rename to observableState
  var observedState: State {
    get {
      // TODO: should we skip this if State is not ObservableState?
      self._$observationRegistrar.access(self, keyPath: \.observedState)
      return self.stateSubject.value
    }
    set {
      if !isIdentityEqual(self.stateSubject.value, newValue) {
        self._$observationRegistrar.withMutation(of: self, keyPath: \.observedState) {
          self.stateSubject.value = newValue
        }
      } else {
        self.stateSubject.value = newValue
      }
    }
  }
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
extension Store where State: ObservableState {
  private(set) public var state: State {
    get { self.observedState }
    set { self.observedState = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}
