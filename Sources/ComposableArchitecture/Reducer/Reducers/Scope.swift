/// Embeds a child reducer in a parent domain.
///
/// This reducer takes a writable key path or case path from parent state to child state, as well as
/// a case path from parent action to child action, and uses them to run a child reducer against
/// that portion of the parent domain.
///
/// For example, given a child reducer:
///
/// ```swift
/// struct Child: ReducerProtocol {
///   struct State {
///     // ...
///   }
///
///   enum Action {
///     // ...
///   }
///
///   // ...
/// }
/// ```
///
/// A parent reducer with a domain that holds onto child state and child actions can use
/// ``Scope/init(state:action:_:)`` to embed the child reducer in its ``ReducerProtocol/body``:
///
/// ```swift
/// struct Parent: ReducerProtocol {
///   struct State {
///     var child: Child.State
///     // ...
///   }
///
///   enum Action {
///     case child(Child.Action)
///     // ...
///   }
///
///   var body: some ReducerProtocol<State, Action> {
///     Scope(state: \.child, action: /Action.child) {
///       Child()
///     }
///     // ...
///   }
/// }
/// ```
///
/// If the parent reducer models its state in an enum, it can use
/// ``Scope/init(state:action:_:file:fileID:line:)`` instead:
///
/// ```swift
/// struct Parent: ReducerProtocol {
///   enum State {
///     case child(Child.State)
///     // ...
///   }
///
///   enum Action {
///     case child(Child.Action)
///     // ...
///   }
///
///   var body: some ReducerProtocol<State, Action> {
///     Scope(state: /State.child, action: /Action.child) {
///       Child()
///     }
///     // ...
///   }
/// }
/// ```
public struct Scope<ParentState, ParentAction, Child: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  enum StatePath {
    case casePath(
      CasePath<ParentState, Child.State>, file: StaticString, fileID: StaticString, line: UInt
    )
    case keyPath(WritableKeyPath<ParentState, Child.State>)
  }

  @usableFromInline
  let toChildState: StatePath

  @usableFromInline
  let toChildAction: CasePath<ParentAction, Child.Action>

  @usableFromInline
  let child: Child

  /// Initializes a reducer that runs the given child reducer against a subset of parent state and
  /// actions.
  ///
  /// - Parameters:
  ///   - toChildState: A writable key path from parent state to a property containing child state.
  ///   - toChildAction: A case path from parent action to a case containing child actions.
  ///   - child: A reducer that will be invoked with child actions against child state.
  @inlinable
  public init(
    state toChildState: WritableKeyPath<ParentState, Child.State>,
    action toChildAction: CasePath<ParentAction, Child.Action>,
    @ReducerBuilderOf<Child> _ child: () -> Child
  ) {
    self.toChildState = .keyPath(toChildState)
    self.toChildAction = toChildAction
    self.child = child()
  }

  /// Initializes a reducer that runs the given child reducer against a subset of parent state and
  /// actions.
  ///
  /// - Parameters:
  ///   - toChildState: A case path from parent state to a case containing child state.
  ///   - toChildAction: A case path from parent action to a case containing child actions.
  ///   - child: A reducer that will be invoked with child actions against child state.
  @inlinable
  public init(
    state toChildState: CasePath<ParentState, Child.State>,
    action toChildAction: CasePath<ParentAction, Child.Action>,
    @ReducerBuilderOf<Child> _ child: () -> Child,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.toChildState = .casePath(toChildState, file: file, fileID: fileID, line: line)
    self.toChildAction = toChildAction
    self.child = child()
  }

  @inlinable
  public func reduce(
    into state: inout ParentState, action: ParentAction
  ) -> Effect<ParentAction, Never> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    switch self.toChildState {
    case let .casePath(toChildState, file, fileID, line):
      guard var childState = toChildState.extract(from: state) else {
        // TODO: Update language
        runtimeWarning(
          """
          A reducer scoped at "%@:%d" received an action when child state was unavailable. …

            Action:
              %@

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • Another reducer set "%@" to a different case before this reducer ran. Combine or run \
          case-specific reducers before reducers that may set their state to another case. This \
          ensures that case-specific reducers can handle their actions while their state is \
          available.

          • An in-flight effect emitted this action when state was unavailable. While it may be \
          perfectly reasonable to ignore this action, you may want to cancel the associated \
          effect before state is set to another case, especially if it is a long-living effect.

          • This action was sent to the store while state was another case. Make sure that \
          actions for this reducer can only be sent to a view store when state is non-"nil". \
          In SwiftUI applications, use "SwitchStore".
          """,
          [
            "\(fileID)",
            line,
            debugCaseOutput(childAction),
            "\(ParentState.self)",
          ],
          file: file,
          line: line
        )
        return .none
      }
      defer { state = toChildState.embed(childState) }

      return self.child
        .reduce(into: &childState, action: childAction)
        .map(self.toChildAction.embed)

    case let .keyPath(toChildState):
      return self.child
        .reduce(into: &state[keyPath: toChildState], action: childAction)
        .map(self.toChildAction.embed)
    }
  }
}
