/// Embeds a child reducer in a parent domain.
///
/// `Scope` is a tool for slicing applications and features into smaller and smaller units that are
/// easier to understand, test, and package into isolated modules. Each scoped unit can then be
/// assembled into larger and larger domains to form a single reducer that powers a large feature or
/// even an entire application.
///
/// You hand `Scope` a child reducer that you want to run on a slice of parent domain, as well as
/// key paths and case paths that describe where to find the child in the parent. When run, it will
/// intercept and feeds child actions alongside that slice of child state to the child reducer so
/// that it can be updated in the parent.
///
/// For example, given the basic scaffolding of child reducer:
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
/// ``init(state:action:_:)`` to embed the child reducer in its
/// ``ReducerProtocol/body-swift.property-5mc0o``:
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
/// If the parent reducer models its state in an enum, use
/// ``init(state:action:_:file:fileID:line:)`` with a case path instead of a writable key path.
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

  /// Initializes a reducer that runs the given child reducer against a slice of parent state and
  /// actions.
  ///
  /// Useful for combining child reducers into a parent.
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   Scope(state: \.profile, action: /Action.profile) {
  ///     Profile()
  ///   }
  ///   Scope(state: \.settings, action: /Action.settings) {
  ///     Settings()
  ///   }
  ///   // ...
  /// }
  /// ```
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

  /// Initializes a reducer that runs the given child reducer against a slice of parent state and
  /// actions.
  ///
  /// Useful for combining reducers of mutually-exclusive enum state.
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   Scope(state: /State.loggedIn, action: /Action.loggedIn) {
  ///     LoggedIn()
  ///   }
  ///   Scope(state: /State.loggedOut, action: /Action.loggedOut) {
  ///     LoggedOut()
  ///   }
  /// }
  /// ```
  ///
  /// > Warning: Be careful when assembling reducers that are scoped to cases of enum state. If a
  /// > scoped reducer receives a child action when its state is set to an unrelated case, it will
  /// > not be able to process the action, which is considered an application logic error and will
  /// > emit runtime warnings.
  /// >
  /// > This can happen if another reducer in the parent domain changes the child state to an
  /// > unrelated case when it handles the action _before_ the scoped reducer runs. For example, a
  /// > parent may receive a dismissal action from the child domain:
  /// >
  /// > ```swift
  /// > Reduce { state, action in
  /// >   switch action {
  /// >   case .loggedIn(.quitButtonTapped):
  /// >     state = .loggedOut(LoggedOut.State())
  /// >   // ...
  /// >   }
  /// > }
  /// > Scope(state: /State.loggedIn, action: /Action.loggedIn) {
  /// >   LoggedIn()  // ⚠️ Logged-in domain can't handle `quitButtonTapped`
  /// > }
  /// > ```
  /// >
  /// > If the parent domain contains additional logic for switching between cases of child state,
  /// > prefer ``ReducerProtocol/ifCaseLet(_:action:then:file:fileID:line:)``, which better ensures
  /// > that child logic runs _before_ any parent logic can replace child state:
  /// >
  /// > ```swift
  /// > Reduce { state, action in
  /// >   switch action {
  /// >   case .loggedIn(.quitButtonTapped):
  /// >     state = .loggedOut(LoggedOut.State())
  /// >   // ...
  /// >   }
  /// > }
  /// > .ifCaseLet(state: /State.loggedIn, action: /Action.loggedIn) {
  /// >   LoggedIn()  // ✅ Receives actions before its case can change
  /// > }
  /// > ```
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
