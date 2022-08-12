// TODO: Should this be another initializer on `Scope`, instead?
// TODO: Should we prefer using `ifLet`, or `ifCaseLet`, or `switch` instead? (On `EmptyReducer`?)

/// Embeds a child reducer in a parent domain by scoping the parent domain to a case that holds
/// child domain.
///
/// This reducer takes a case path from parent state to child state, as well as a case path from
/// parent action to child action, and uses them to run a child reducer against that portion of the
/// parent domain.
///
/// For example, given a child reducer:
///
/// ```swift
/// struct Child: ReducerProtocol {
///   struct State { ... }
///
///   enum Action { ... }
///
///   ...
/// }
/// ```
///
/// A parent reducer with a domain that holds onto child state and child actions can use `ScopeCase`
/// to embed the child reducer in its ``ReducerProtocol/body``:
///
/// ```swift
/// struct Parent: ReducerProtocol {
///   enum State {
///     case child(Child.State)
///     ...
///   }
///
///   enum Action {
///     case child(Child.Action)
///     ...
///   }
///
///   var body: some ReducerProtocol<State, Action> {
///     ScopeCase(state: /State.child, action: /Action.child) {
///       Child()
///     }
///     ...
///   }
/// }
/// ```
///
/// To scope parent state to a property, see ``Scope``.
public struct ScopeCase<State, Action, Child: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let toChildState: CasePath<State, Child.State>

  @usableFromInline
  let toChildAction: CasePath<Action, Child.Action>

  @usableFromInline
  let child: Child

  @inlinable
  public init(
    state toChildState: CasePath<State, Child.State>,
    action toChildAction: CasePath<Action, Child.Action>,
    @ReducerBuilderOf<Child> _ child: () -> Child
  ) {
    self.toChildState = toChildState
    self.toChildAction = toChildAction
    self.child = child()
  }

  @inlinable
  public func reduce(
    into state: inout State, action: Action
  ) -> Effect<Action, Never> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }

    guard var childState = self.toChildState.extract(from: state) else {
      //      runtimeWarning(
      //        """
      //        A reducer pulled back from "%@:%d" received an action when local state was \
      //        unavailable. …
      //
      //          Action:
      //            %@
      //
      //        This is generally considered an application logic error, and can happen for a few \
      //        reasons:
      //
      //        • The reducer for a particular case of state was combined with or run from another \
      //        reducer that set "%@" to another case before the reducer ran. Combine or run \
      //        case-specific reducers before reducers that may set their state to another case. This \
      //        ensures that case-specific reducers can handle their actions while their state is \
      //        available.
      //
      //        • An in-flight effect emitted this action when state was unavailable. While it may be \
      //        perfectly reasonable to ignore this action, you may want to cancel the associated \
      //        effect before state is set to another case, especially if it is a long-living effect.
      //
      //        • This action was sent to the store while state was another case. Make sure that \
      //        actions for this reducer can only be sent to a view store when state is non-"nil". \
      //        In SwiftUI applications, use "SwitchStore".
      //        """,
      //        [
      //          "\(file)",
      //          line,
      //          debugCaseOutput(localAction),
      //          "\(State.self)",
      //        ]
      //      )
      return .none
    }
    defer { state = self.toChildState.embed(childState) }

    return self.child
      .reduce(into: &childState, action: childAction)
      .map(self.toChildAction.embed)
  }
}
