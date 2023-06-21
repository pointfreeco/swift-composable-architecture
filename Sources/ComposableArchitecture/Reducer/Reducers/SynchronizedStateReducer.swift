import Foundation

/// Parameters for `withSynchronizedState` for `Reducer`.
/// This allows providing the reducer with what state to watch and how to
/// synchronize it with parent and other siblings.
public struct SynchronizationParameters<Root, Value> {

  public init(
    parent: SynchronizationType<Root, Value>,
    children: [SynchronizationType<Root, Value>]
  ) {
    self.parent = parent
    self.children = children
  }

  var parent: SynchronizationType<Root, Value>
  var children: [SynchronizationType<Root, Value>]

  /// Defines how to synchronize state amongst the reducers.
  public enum SynchronizationType<Root, Value> {

    /// Only observe this piece of state for changes.
    case observeOnly(KeyPath<Root, Value>)

    /// Only update this piece of state if anything changes. But do not
    /// propagate its changes to parent or siblings.
    case updateOnly(WritableKeyPath<Root, Value>)

    /// Update this piece of state if anything else on the parent changed
    /// or either of the siblings change. Also if this state changes itself
    /// communicate that to parent and siblings.
    case synchronize(WritableKeyPath<Root, Value>)
  }
}

extension ReducerProtocol {
  /// Allows observing a piece of state and synchronizing it across
  /// a `Reducer`'s children. This can be configured to either only
  /// observe or update the state, or all of that if needed.
  ///
  /// The order of priority for state changes assumes that parent state if observable will
  /// supersede the children state. However, since the reducer does execute one action at a time
  /// if used correctly this should not be an issue. The order of priority amongst the children
  /// is just the first change in the `children` array.
  ///
  /// For example, if a parent feature holds onto a piece state that is needed by its children
  /// _and_ the state can be mutated `synchronizeState` operator can allow ensuring
  /// the states stay in-sync without additional actions to keep it up to date.
  ///
  /// ```swift
  /// struct Child: ReducerProtocol {
  ///  struct State {
  ///     var sharedState: Foo
  ///     // ..
  ///   }
  ///
  ///   enum Action ...
  /// }
  /// struct Parent: ReducerProtocol {
  ///   struct State {
  ///     var sharedState: Foo
  ///     var child: Child.State
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case child(Child.Action)
  ///     // ...
  ///   }
  ///
  ///   var body: some ReducerProtocol<State, Action> {
  ///     Reduce { state, action in
  ///       Scope(state: \.child, action: /Action.child) {
  ///         Child()
  ///       }
  ///
  ///       // Core logic for parent feature
  ///     }
  ///     .synchronizeState(
  ///         over: SynchronizationParameters(
  ///             parent: .observeOnly(\State.sharedState),
  ///             children: [
  ///                  .synchronize(\State.child.sharedState)
  ///             ]
  ///         )
  ///     )
  ///   }
  /// }
  /// ```
  public func synchronizeState<Value: Equatable>(
    over synchronizationParameters: SynchronizationParameters<Self.State, Value>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _SynchronizedStateReducer<Self, Value> {
    return _SynchronizedStateReducer(
      parent: self,
      synchronizationParameters: synchronizationParameters,
      fileID: fileID,
      line: line
    )
  }
}

public struct _SynchronizedStateReducer<Parent: ReducerProtocol, Value: Equatable>: ReducerProtocol
{
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @usableFromInline
  let synchronizationParameters: SynchronizationParameters<Parent.State, Value>

  @usableFromInline
  init(
    parent: Parent,
    synchronizationParameters: SynchronizationParameters<Parent.State, Value>,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.synchronizationParameters = synchronizationParameters
    self.fileID = fileID
    self.line = line
  }

  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> EffectTask<Parent.Action> {

    // Get parent and children states before running the reducer.
    let parentStateBeforeTransformation = state[keyPath: synchronizationParameters.parent.keypath]
    let childrenStateBeforeTransformation = synchronizationParameters.children.map {
      childParam -> Value? in
      if let keypath = childParam.observableKeypath {
        return state[keyPath: keypath]
      }
      return nil
    }

    let effects = self.parent.reduce(into: &state, action: action)

    // If we can observe the parent and parent state changed, then
    // write the new state and return effects.
    if let observable = synchronizationParameters.parent.observableKeypath,
      state[keyPath: observable] != parentStateBeforeTransformation
    {
      synchronizationParameters.children
        .compactMap { $0.writableKeypath }
        .forEach { keypath in
          state[keyPath: keypath] = state[keyPath: observable]
        }

      return effects
    }

    // If we can observe the parent, then check for state changes
    // with children and pick the first change.
    let childrenStateAfterTransformation = synchronizationParameters.children.map {
      childParam -> Value? in
      if let keypath = childParam.observableKeypath {
        return state[keyPath: keypath]
      }
      return nil
    }

    if let newState = zip(childrenStateBeforeTransformation, childrenStateAfterTransformation)
      .first(where: { $0 != $1 })?.1
    {

      // We can update the parent and other siblings that are allowed.
      ([synchronizationParameters.parent.writableKeypath]
        + synchronizationParameters.children.map(\.writableKeypath))
        .compactMap { $0 }
        .forEach {
          state[keyPath: $0] = newState
        }
    }

    return effects
  }
}

extension SynchronizationParameters.SynchronizationType {
  /// Get a read only keypath to observe for changes.
  var observableKeypath: KeyPath<Root, Value>? {
    switch self {
    case .observeOnly(let keyPath):
      return keyPath
    case .updateOnly:
      return nil
    case .synchronize(let writableKeyPath):
      return writableKeyPath
    }
  }

  /// Get a writable keypath to update for changes.
  var writableKeypath: WritableKeyPath<Root, Value>? {
    switch self {
    case .observeOnly:
      return nil
    case .updateOnly(let writableKeyPath):
      return writableKeyPath
    case .synchronize(let writableKeyPath):
      return writableKeyPath
    }
  }

  /// Get a read only keypath to observe for changes.
  var keypath: KeyPath<Root, Value> {
    switch self {
    case .observeOnly(let keyPath):
      return keyPath
    case .updateOnly(let keyPath):
      return keyPath
    case .synchronize(let keyPath):
      return keyPath
    }
  }
}
