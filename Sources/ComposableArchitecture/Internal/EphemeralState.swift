@_spi(Reflection) import CasePaths

/// Loosely represents features that are only briefly shown and the first time they are interacted
/// with they go away. Such features do not manage any behavior on the inside.
///
/// Alerts and confirmation dialogs are examples of this kind of state.
public protocol _EphemeralState {
  static var actionType: Any.Type { get }
}

extension AlertState: _EphemeralState {
  public static var actionType: Any.Type { Action.self }
}

@available(iOS 13, macOS 12, tvOS 13, watchOS 6, *)
extension ConfirmationDialogState: _EphemeralState {
  public static var actionType: Any.Type { Action.self }
}

@usableFromInline
func ephemeralType<State>(of state: State) -> (any _EphemeralState.Type)? {
  (State.self as? any _EphemeralState.Type)
    ?? EnumMetadata(type(of: state)).flatMap { metadata in
      metadata.associatedValueType(forTag: metadata.tag(of: state))
        as? any _EphemeralState.Type
    }
}

@usableFromInline
func isEphemeral<State>(_ state: State) -> Bool {
  ephemeralType(of: state) != nil
}

extension _EphemeralState {
  @usableFromInline
  static func canSend<Action>(_ action: Action) -> Bool {
    return Action.self == Self.actionType
      || EnumMetadata(Action.self).flatMap { metadata in
        metadata.associatedValueType(forTag: metadata.tag(of: action)) == Self.actionType
      } == true
  }
}
