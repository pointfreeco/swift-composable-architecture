/// Loosely represents features that are only briefly shown and the first time they are interacted
/// with they go away. Such features do not manage any behavior on the inside.
///
/// Alerts and confirmation dialogs are examples of this kind of state.
public protocol _EphemeralState {}

extension AlertState: _EphemeralState {}

@available(iOS 13, macOS 12, tvOS 13, watchOS 6, *)
extension ConfirmationDialogState: _EphemeralState {}
