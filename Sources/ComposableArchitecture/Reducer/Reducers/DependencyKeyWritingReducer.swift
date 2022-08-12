extension ReducerProtocol {
  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> DependencyKeyWritingReducer<Self> {
    .init(base: self) { $0[keyPath: keyPath] = value }
  }
}

public struct DependencyKeyWritingReducer<Base: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let base: Base

  @usableFromInline
  let update: (inout DependencyValues) -> Void

  @usableFromInline
  init(base: Base, update: @escaping (inout DependencyValues) -> Void) {
    self.base = base
    self.update = update
  }

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> Effect<Base.Action, Never> {
    var values = DependencyValues.current
    self.update(&values)
    return DependencyValues.$current.withValue(values) {
      self.base.reduce(into: &state, action: action)
    }
  }

  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> Self {
    .init(base: self.base) { values in
      self.update(&values)
      values[keyPath: keyPath] = value
    }
  }
}
