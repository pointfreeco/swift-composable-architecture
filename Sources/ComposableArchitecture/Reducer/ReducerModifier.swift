public protocol ReducerModifier {
  associatedtype Base: ReducerProtocol
  associatedtype Body: ReducerProtocol

  @ReducerBuilder<Body.State, Body.Action>
  func body(_ base: Base) -> Body
}

extension ReducerProtocol {
  @inlinable
  public func modifier<R: ReducerModifier>(_ modifier: R) -> _ModifiedReducer<Self, R> {
    _ModifiedReducer(base: self, modifier: modifier)
  }
}

public struct _ModifiedReducer<Base: ReducerProtocol, Modifier: ReducerModifier>: ReducerProtocol
where Modifier.Base == Base {
  @usableFromInline
  let base: Base

  @usableFromInline
  let modifier: Modifier

  @usableFromInline
  init(base: Base, modifier: Modifier) {
    self.base = base
    self.modifier = modifier
  }

  @inlinable
  public var body: Modifier.Body {
    self.modifier.body(self.base)
  }
}
