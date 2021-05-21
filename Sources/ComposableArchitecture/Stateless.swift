import Foundation

/// A helper to using Stateless in IfLetStore
/// Example case:
/// struct State {
///   var childState: Stateless?
/// }
///
/// enum AppAction {
///   case child(ChildAction)
/// }
///
/// Type of ChildView store is Store<Void, ChildAction>
///
///     IfLetStore(
///       store.scope(state: \.childState, action: AppAction.child),
///       then: ChildView.init(store:),
///       else: { Text("No Child") }
///     )
///
public struct Stateless: Equatable {
  public init() {}
}
