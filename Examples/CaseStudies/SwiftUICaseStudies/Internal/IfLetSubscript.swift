extension Optional {
  public subscript<Value>(ifLet keyPath: WritableKeyPath<Wrapped, Value>) -> Value? {
    get {
      self.map { $0[keyPath: keyPath] }
    }
    set {
      guard let newValue = newValue else { return }
      self?[keyPath: keyPath] = newValue
    }
  }
}
