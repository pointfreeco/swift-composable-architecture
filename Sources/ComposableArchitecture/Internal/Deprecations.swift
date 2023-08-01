@available(*, unavailable, renamed: "Effect")
public typealias EffectTask = Effect

@available(*, unavailable, renamed: "Reducer")
public typealias ReducerProtocol = Reducer

#if swift(>=5.7.1)
  @available(*, unavailable, renamed: "ReducerOf")
  public typealias ReducerProtocolOf<R: Reducer> = Reducer<R.State, R.Action>
#endif
