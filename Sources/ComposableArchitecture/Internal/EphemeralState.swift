public protocol _EphemeralState {}

extension AlertState: _EphemeralState {}
@available(iOS 13, macOS 12, tvOS 13, watchOS 6, *)
extension ConfirmationDialogState: _EphemeralState {}
