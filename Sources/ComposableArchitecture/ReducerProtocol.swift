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
