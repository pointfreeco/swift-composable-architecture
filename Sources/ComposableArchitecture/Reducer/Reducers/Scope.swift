/// Embeds a child reducer in a parent domain by scoping the parent domain to a property that holds
/// child domain.
///
/// This reducer takes a writable key path from parent state to child state, as well as a case path
/// from parent action to child action, and uses them to run a child reducer against that portion of
/// the parent domain.
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
/// A parent reducer with a domain that holds onto child state and child actions can use `Scope` to
/// embed the child reducer in its ``ReducerProtocol/body``:
///
/// ```swift
/// struct Parent: ReducerProtocol {
///   struct State {
///     var child: Child.State
///     ...
///   }
///
///   enum Action {
///     case child(Child.Action)
///     ...
///   }
///
///   var body: some ReducerProtocol<State, Action> {
///     Scope(state: \.child, action: /Action.child) {
///       Child()
///     }
///     ...
///   }
/// }
/// ```
///
/// To scope parent enum state to a child case, see ``ScopeCase``.
public struct Scope<State, Action, Child: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let toChildState: WritableKeyPath<State, Child.State>

  @usableFromInline
  let toChildAction: CasePath<Action, Child.Action>

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
    state toChildState: WritableKeyPath<State, Child.State>,
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
    return self.child
      .reduce(into: &state[keyPath: self.toChildState], action: childAction)
      .map(self.toChildAction.embed)
  }
}
