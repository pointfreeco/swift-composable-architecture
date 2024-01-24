@_spi(Reflection) import CasePaths

/// Loosely represents features that are only briefly shown and the first time they are interacted
/// with they go away. Such features do not manage any behavior on the inside.
///
/// Alerts and confirmation dialogs are examples of this kind of state.
public protocol _EphemeralState<Action>: CaseReducer, CaseReducerState {
  associatedtype Reducer = Self
  static var actionType: Action.Type { get }
}

#if swift(>=5.8)
  @_documentation(visibility:private)
  extension AlertState: _EphemeralState {
    public static var actionType: Action.Type { Action.self }
  }
  @_documentation(visibility:private)
  @available(iOS 13, macOS 12, tvOS 13, watchOS 6, *)
  extension ConfirmationDialogState: _EphemeralState {
    public static var actionType: Action.Type { Action.self }
  }
#else
  extension AlertState: _EphemeralState {
    public static var actionType: Action.Type { Action.self }
  }
  @available(iOS 13, macOS 12, tvOS 13, watchOS 6, *)
  extension ConfirmationDialogState: _EphemeralState {
    public static var actionType: Action.Type { Action.self }
  }
#endif

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

public struct _EphemeralStateCaseScope<State: _EphemeralState> {
  let store: Store<State, State.Action>
}

extension _EphemeralState {
  public static func scope(_ store: Store<Self, Action>) -> _EphemeralStateCaseScope<Self> {
    _EphemeralStateCaseScope(store: store)
  }
  public static var body: some ComposableArchitecture.Reducer<Self, Action> {
    EmptyReducer()
  }
}
