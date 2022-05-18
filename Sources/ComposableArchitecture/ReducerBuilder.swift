import Combine
@resultBuilder
public enum ReducerBuilder<State, Action> {
  @inlinable
  public static func buildExpression<R: ReducerProtocol<State, Action>>(_ expression: R) -> R where R.Body == R {
    expression
  }

  @inlinable
  public static func buildExpression<R: ReducerProtocol<State, Action>>(_ expression: R) -> R {
    expression
  }

  @inlinable
  public static func buildBlock() -> EmptyReducer<State, Action> {
    .init()
  }

  @inlinable
  public static func buildPartialBlock<R: ReducerProtocol<State, Action>>(first: R) -> R {
    first
  }

  @inlinable
  public static func buildPartialBlock<
    R0: ReducerProtocol<State, Action>, R1: ReducerProtocol<State, Action>
  >(accumulated: R0, next: R1) -> Sequence<R0, R1> {
    .init(r0: accumulated, r1: next)
  }

  public struct Sequence<R0: ReducerProtocol, R1: ReducerProtocol>: ReducerProtocol
  where R0.State == R1.State, R0.Action == R1.Action {
    @usableFromInline
    let r0: R0

    @usableFromInline
    let r1: R1

    @usableFromInline
    init(r0: R0, r1: R1) {
      self.r0 = r0
      self.r1 = r1
    }

    @inlinable
    public func reduce(into state: inout R0.State, action: R0.Action) -> Effect<R0.Action, Never> {
      Publishers.Merge(
        self.r0.reduce(into: &state, action: action),
        self.r1.reduce(into: &state, action: action)
      ).eraseToEffect()
    }
  }
}
