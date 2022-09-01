extension ReducerProtocol {
  /// Sets the dependency value of the specified key path to the given value.
  ///
  /// - Parameters:
  ///   - keyPath: A key path that indicates the property of the `DependencyValues` structure to
  ///     update.
  ///   - value: The new value to set for the item specified by `keyPath`.
  /// - Returns: A reducer that has the given value set in its dependencies.
  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  )
  // NB: We should not return `some ReducerProtocol<State, Action>` here. That would prevent the
  //     specialization defined below from being called, which fuses chained calls to `dependency`.
  -> _DependencyKeyWritingReducer<Self> {
    _DependencyKeyWritingReducer(base: self) { $0[keyPath: keyPath] = value }
  }

  /// Modifies a reducer's dependencies with a closure.
  ///
  /// - Parameter update: A closure that is handed a mutable instance of dependency values.
  @inlinable
  public func dependencies(_ update: @escaping (inout DependencyValues) -> Void)
  // NB: We should not return `some ReducerProtocol<State, Action>` here. That would prevent the
  //     specialization defined below from being called, which fuses chained calls to `dependency`.
  -> _DependencyKeyWritingReducer<Self> {
    _DependencyKeyWritingReducer(base: self, update: update)
  }
}

public struct _DependencyKeyWritingReducer<Base: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let base: Base

  @usableFromInline
  let update: (inout DependencyValues) -> Void

  @inlinable
  init(base: Base, update: @escaping (inout DependencyValues) -> Void) {
    self.base = base
    self.update = update
  }

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> Effect<Base.Action, Never> {
    return DependencyValues.withValues {
      self.update(&$0)
    } operation: {
      self.base.reduce(into: &state, action: action)
    }
  }

  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> Self {
    .init(base: self.base) { values in
      values[keyPath: keyPath] = value
      self.update(&values)
    }
  }
}
