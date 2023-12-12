
struct MyState: ObservableState {
  private var _count = 0
  var count: Int {
    @storageRestrictions(initializes: _count)
    init(initialValue) {
      _count = initialValue
    }
    get {
      _$observationRegistrar.access(self, keyPath: \.count)
      return _count
    }
    set {
      _$observationRegistrar.mutate(self, keyPath: \.count, &_count, newValue, _$isIdentityEqual)
    }
    _modify {
      let oldValue = _$observationRegistrar.willSet(self, keyPath: \.count, &_count)
      defer {
        _$observationRegistrar.didSet(self, keyPath: \.count, &_count, oldValue, _$isIdentityEqual)
      }
      yield &_count
    }
  }

  var _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()
  var _$id: ComposableArchitecture.ObservableStateID {
    self._$observationRegistrar.id
  }
  mutating func _$willSet() {
    self._$observationRegistrar.id._flag = true
  }
  mutating func _$didSet() {
    self._$observationRegistrar.id._flag = false
  }
}
