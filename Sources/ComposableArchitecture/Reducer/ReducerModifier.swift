//public struct _ReducerModifierContent<Modifier: ReducerModifier>: ReducerProtocol {
//  public typealias State = Modifier.Body.State
//
//  public typealias Action = Modifier.Body.Action
//
//  public func reduce(into state: inout Modifier.Body.State, action: Modifier.Body.Action) -> Effect<Modifier.Body.Action, Never> {
//    fatalError()
//  }
//}
//
//public protocol ReducerModifier {
//  associatedtype Body: ReducerProtocol
//
//  //  @ReducerBuilder<Body.State, Body.Action>
//  //  func body<Base: ReducerProtocol>(_ base: Base) -> Body
//  //  where Base.State == Body.State, Base.Action == Body.Action
//
//  @ReducerBuilder<Body.State, Body.Action>
//  func body(_ content: Content) -> Body
//}
//
//extension ReducerModifier {
//  public typealias Content = _ReducerModifierContent<Self>
//}
//
////extension ReducerProtocol {
////  @inlinable
////  public func modifier<R: ReducerModifier>(_ modifier: R) -> _ModifiedReducer<Self, R> {
////    _ModifiedReducer(base: self, modifier: modifier)
////  }
////}
////
////public struct _ModifiedReducer<Base: ReducerProtocol, Modifier: ReducerModifier>: ReducerProtocol
////where Base.State == Modifier.Body.State, Base.Action == Modifier.Body.Action {
////  @usableFromInline
////  let base: Base
////
////  @usableFromInline
////  let modifier: Modifier
////
////  @usableFromInline
////  init(base: Base, modifier: Modifier) {
////    self.base = base
////    self.modifier = modifier
////  }
////
////  @inlinable
////  public var body: Modifier.Body {
////    self.modifier.body(self.base)
////  }
////}
//
//public struct M<State, Action>: ReducerModifier {
//  public func body(_ content: Content) -> some ReducerProtocol<State, Action> {
//    EmptyReducer()
//  }
//}
