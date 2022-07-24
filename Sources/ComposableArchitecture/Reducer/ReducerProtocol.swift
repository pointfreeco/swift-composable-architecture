#if compiler(>=5.7)
  public protocol ReducerProtocol<State, Action> {
    associatedtype State

    associatedtype Action

    associatedtype Body

    func reduce(into state: inout State, action: Action) -> Effect<Action, Never>

    @ReducerBuilder<State, Action>
    var body: Body { get }
  }
#else
  public protocol ReducerProtocol: _ReducerBody {
    associatedtype State

    associatedtype Action

    associatedtype Body

    func reduce(into state: inout State, action: Action) -> Effect<Action, Never>

    @ReducerBuilder<State, Action>
    var body: Body { get }
  }
#endif

extension ReducerProtocol where Body == Never {
  @_transparent
  public var body: Body {
    fatalError(
      """
      '\(Self.self)' has no body. …

      Do not access a reducer's 'body' property directly, as it may not exist. To run a reducer, \
      call 'Reducer.reduce(into:action:)', instead.
      """
    )
  }
}

extension ReducerProtocol where Body: ReducerProtocol, Body.State == State, Body.Action == Action {
  @inlinable
  public func reduce(
    into state: inout Body.State, action: Body.Action
  ) -> Effect<Body.Action, Never> {
    self.body.reduce(into: &state, action: action)
  }
}
