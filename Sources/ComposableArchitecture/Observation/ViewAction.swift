public protocol ViewAction<ViewAction> {
  associatedtype ViewAction
  static func view(_ action: ViewAction) -> Self
}
