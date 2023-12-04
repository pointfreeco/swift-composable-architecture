/// Defines the actions that can be sent from a view.
///
/// See the ``ViewAction(for:)`` macro for more information on how to use this.
public protocol ViewAction<ViewAction> {
  associatedtype ViewAction
  static func view(_ action: ViewAction) -> Self
}
