extension ReducerProtocol {
  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> DependencyKeyWritingReducer<Self, Value> {
    .init(upstream: self) { $0[keyPath: keyPath] = value }
  }
}

public struct DependencyKeyWritingReducer<Upstream: ReducerProtocol, Value>: ReducerProtocol {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  let update: (inout DependencyValues) -> Void

  @usableFromInline
  init(upstream: Upstream, update: @escaping (inout DependencyValues) -> Void) {
    self.upstream = upstream
    self.update = update
  }

  @inlinable
  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    var values = DependencyValues.current
    self.update(&values)
    return DependencyValues.$current.withValue(values) {
      self.upstream.reduce(into: &state, action: action)
    }
  }

  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> Self {
    .init(upstream: self.upstream) { values in
      self.update(&values)
      values[keyPath: keyPath] = value
    }
  }
}
