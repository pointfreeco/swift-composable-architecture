import SwiftUI
extension _Reducer {
  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> Reducers.DependencyKeyWritingReducer<Self, Value> {
    .init(upstream: self, keyPath: keyPath, value: value)
  }
}

extension Reducers {
  public struct DependencyKeyWritingReducer<Upstream, Value>: _Reducer
  where Upstream: _Reducer
  {
    public let upstream: Upstream
    public let keyPath: WritableKeyPath<DependencyValues, Value>
    public let value: Value

    @inlinable
    public init(
      upstream: Upstream,
      keyPath: WritableKeyPath<DependencyValues, Value>,
      value: Value
    ) {
      self.upstream = upstream
      self.keyPath = keyPath
      self.value = value
    }

    @inlinable
    public func reduce(into state: inout Upstream.State, action: Upstream.Action)
    -> Effect<Upstream.Action, Never> {
      // TODO: push and pop dependency context
      DependencyValues.shared[keyPath: self.keyPath] = value
      return self.upstream.reduce(into: &state, action: action)
    }
  }
}
