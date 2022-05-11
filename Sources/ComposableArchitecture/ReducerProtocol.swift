public protocol ReducerProtocol<State, Action> {
  associatedtype State

  associatedtype Action

  associatedtype Body: ReducerProtocol<State, Action> = Self

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never>

  @ReducerBuilder<State, Action>
  var body: Body { get }
}

extension ReducerProtocol where Body == Self {
  @inlinable
  public var body: Body {
    self
  }
}

extension ReducerProtocol {
  @inlinable
  public func reduce(
    into state: inout Body.State, action: Body.Action
  ) -> Effect<Body.Action, Never> {
    self.body.reduce(into: &state, action: action)
  }
}

extension Reducer where Environment == Void {
  public init<R: ReducerProtocol<State, Action>>(_ reducer: R) {
    self.init { state, action, _ in reducer.reduce(into: &state, action: action) }
  }
}

extension Store {
  public convenience init<R: ReducerProtocol<State, Action>>(
    initialState: State,
    reducer: R
  ) {
    self.init(
      initialState: initialState,
      reducer: .init(reducer),
      environment: ()
    )
  }
}
