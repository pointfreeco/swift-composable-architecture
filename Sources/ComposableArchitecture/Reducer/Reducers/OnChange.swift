extension ReducerProtocol {
  /// Adds a reducer to run when this reducer changes the given value in state.
  ///
  /// Use this operator to trigger additional logic when a value changes, like when a
  /// ``BindingReducer`` makes a deeper change to a struct held in ``BindingState``.
  ///
  /// ```swift
  /// struct Settings: ReducerProtocol {
  ///   struct State {
  ///     @BindingState var userSettings: UserSettings
  ///     // ...
  ///   }
  ///
  ///   enum Action: BindableAction {
  ///     case binding(BindingAction<State>)
  ///     // ...
  ///   }
  ///
  ///   var body: some ReducerProtocol<State, Action> {
  ///     BindingReducer()
  ///       .onChange(of: \.userSettings.isHapticFeedbackEnabled) { oldValue, newValue in
  ///         Reduce { state, action in
  ///           .run { send in
  ///             // Persist new value...
  ///           }
  ///         }
  ///       }
  ///   }
  /// }
  /// ```
  ///
  /// When the value changes, the new version of the closure will be called, so any captured values
  /// will have their values from the time that the observed value has its new value. The system
  /// passes the old and new observed values into the closure.
  ///
  /// > Note: Take care when applying `onChange(of:)` to a reducer, as it adds an equatable check
  /// > for every action fed into it. Prefer applying it to leaf nodes, like ``BindingReducer``,
  /// > against values that are quick to equate.
  ///
  /// - Parameters:
  ///   - toValue: A closure that returns a value from the given state.
  ///   - reducer: A reducer builder closure to run when the value changes.
  ///   - oldValue: The old value that failed the comparison check.
  ///   - newValue: The new value that failed the comparison check.
  /// - Returns: A reducer that performs the
  @inlinable
  public func onChange<V: Equatable, R: ReducerProtocol>(
    of toValue: @escaping (State) -> V,
    @ReducerBuilder<State, Action> _ reducer: @escaping (_ oldValue: V, _ newValue: V) -> R
  ) -> _OnChangeReducer<Self, V, R> {
    _OnChangeReducer(base: self, toValue: toValue, reducer: reducer)
  }
}

public struct _OnChangeReducer<Base: ReducerProtocol, Value: Equatable, Body: ReducerProtocol>:
  ReducerProtocol
where Base.State == Body.State, Base.Action == Body.Action {
  @usableFromInline
  let base: Base

  @usableFromInline
  let toValue: (Base.State) -> Value

  @usableFromInline
  let reducer: (Value, Value) -> Body

  @usableFromInline
  init(
    base: Base,
    toValue: @escaping (Base.State) -> Value,
    reducer: @escaping (Value, Value) -> Body
  ) {
    self.base = base
    self.toValue = toValue
    self.reducer = reducer
  }

  @inlinable
  public func reduce(into state: inout Base.State, action: Base.Action) -> EffectTask<Base.Action> {
    let oldValue = toValue(state)
    let baseEffects = self.base.reduce(into: &state, action: action)
    let newValue = toValue(state)
    return oldValue == newValue
      ? baseEffects
      : .merge(baseEffects, self.reducer(oldValue, newValue).reduce(into: &state, action: action))
  }
}
