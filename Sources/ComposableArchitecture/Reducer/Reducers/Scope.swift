/// Embeds a child reducer in a parent domain.
///
/// ``Scope`` allows you to transform a parent domain into a child domain, and then run a child
/// reduce on that subset domain. This is an important tool for breaking down large features into
/// smaller units and then piecing them together. The smaller units can easier to understand and
/// test, and can even be packaged into their own isolated modules.
///
/// You hand ``Scope`` 3 pieces of data for it to do its job:
///
/// * A writable key path that identifies the child state inside the parent state.
/// * A case path that identifies the child actions inside the parent actions.
/// * A @``ReducerBuilder`` closure that describes the reducer you want to run on the child domain.
///
/// When run, it will intercept all child actions sent and feed them to the child reducer so that
/// it can update the parent state and execute effects.
///
/// For example, given the basic scaffolding of child reducer:
///
/// ```swift
/// struct Child: ReducerProtocol {
///   struct State {
///     // ...
///   }
///   enum Action {
///     // ...
///   }
///   // ...
/// }
/// ```
///
/// A parent reducer with a domain that holds onto the child domain can use
/// ``init(state:action:child:)`` to embed the child reducer in its
/// ``ReducerProtocol/body-swift.property-7foai``:
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
///     Reduce { state, action in
///       // Additional parent logic and behavior
///     }
///   }
/// }
/// ```
///
/// ## Enum state
///
/// The ``Scope`` reducer also works when state is modeled as an enum, not just a struct. In that
/// case you can use ``init(state:action:child:fileID:line:)`` to specify a case path that
/// identifies the case of state you want to scope to.
///
/// For example, if your state was modeled as an enum for unloaded/loading/loaded, you could
/// scope to the loaded case to run a reduce on only that case:
///
/// ```swift
/// struct Feature: ReducerProtocol {
///   enum State {
///     case unloaded
///     case loading
///     case loaded(Child.State)
///   }
///   enum Action {
///     case child(Child.Action)
///     // ...
///   }
///
///   var body: some ReducerProtocol<State, Action> {
///     Scope(state: /State.loaded, action: /Action.child) {
///       Child()
///     }
///     Reduce { state, action in
///       // Additional feature logic and behavior
///     }
///   }
/// }
/// ```
///
/// It is important to note that the order of combine ``Scope`` and your additional feature logic
/// matters. It must be combined before the additional logic. In the other order it would be
/// possible for the feature to intercept a child action, switch the state to another case, and
/// then the scoped child reducer would not be able to react to that action. That can cause subtle
/// bugs, and so we show a runtime warning in that case, and cause test failures.
///
/// For an alternative to using ``Scope`` with state case paths that enforces the order, check out
/// the ``ifCaseLet(_:action:then:fileID:line:)`` operator.
public struct Scope<ParentState, ParentAction, Child: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  enum StatePath {
    case casePath(
      CasePath<ParentState, Child.State>,
      fileID: StaticString,
      line: UInt
    )
    case keyPath(WritableKeyPath<ParentState, Child.State>)
  }

  @usableFromInline
  let toChildState: StatePath

  @usableFromInline
  let toChildAction: CasePath<ParentAction, Child.Action>

  @usableFromInline
  let child: Child

  @usableFromInline
  init(
    toChildState: StatePath,
    toChildAction: CasePath<ParentAction, Child.Action>,
    child: Child
  ) {
    self.toChildState = toChildState
    self.toChildAction = toChildAction
    self.child = child
  }

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
  public init<ChildState, ChildAction>(
    state toChildState: WritableKeyPath<ParentState, ChildState>,
    action toChildAction: CasePath<ParentAction, ChildAction>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child
  ) where ChildState == Child.State, ChildAction == Child.Action {
    self.init(
      toChildState: .keyPath(toChildState),
      toChildAction: toChildAction,
      child: child()
    )
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
  /// > prefer ``ReducerProtocol/ifCaseLet(_:action:then:fileID:line:)``, which better ensures that
  /// > child logic runs _before_ any parent logic can replace child state:
  /// >
  /// > ```swift
  /// > Reduce { state, action in
  /// >   switch action {
  /// >   case .loggedIn(.quitButtonTapped):
  /// >     state = .loggedOut(LoggedOut.State())
  /// >   // ...
  /// >   }
  /// > }
  /// > .ifCaseLet(/State.loggedIn, action: /Action.loggedIn) {
  /// >   LoggedIn()  // ✅ Receives actions before its case can change
  /// > }
  /// > ```
  ///
  /// - Parameters:
  ///   - toChildState: A case path from parent state to a case containing child state.
  ///   - toChildAction: A case path from parent action to a case containing child actions.
  ///   - child: A reducer that will be invoked with child actions against child state.
  @inlinable
  public init<ChildState, ChildAction>(
    state toChildState: CasePath<ParentState, ChildState>,
    action toChildAction: CasePath<ParentAction, ChildAction>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where ChildState == Child.State, ChildAction == Child.Action {
    self.init(
      toChildState: .casePath(toChildState, fileID: fileID, line: line),
      toChildAction: toChildAction,
      child: child()
    )
  }

  @inlinable
  public func reduce(
    into state: inout ParentState, action: ParentAction
  ) -> EffectTask<ParentAction> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    switch self.toChildState {
    case let .casePath(toChildState, fileID, line):
      guard var childState = toChildState.extract(from: state) else {
        runtimeWarn(
          """
          A "Scope" at "\(fileID):\(line)" received a child action when child state was set to a \
          different case. …

            Action:
              \(debugCaseOutput(action))
            State:
              \(debugCaseOutput(state))

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • A parent reducer set "\(typeName(ParentState.self))" to a different case before the \
          scoped reducer ran. Child reducers must run before any parent reducer sets child state \
          to a different case. This ensures that child reducers can handle their actions while \
          their state is still available. Consider using "ReducerProtocol.ifCaseLet" to embed this \
          child reducer in the parent reducer that change its state to ensure the child reducer \
          runs first.

          • An in-flight effect emitted this action when child state was unavailable. While it may \
          be perfectly reasonable to ignore this action, consider canceling the associated effect \
          before child state changes to another case, especially if it is a long-living effect.

          • This action was sent to the store while state was another case. Make sure that actions \
          for this reducer can only be sent from a view store when state is set to the appropriate \
          case. In SwiftUI applications, use "SwitchStore".
          """
        )
        return .none
      }
      defer { state = toChildState.embed(childState) }

      return self.child
        .reduce(into: &childState, action: childAction)
        .map { self.toChildAction.embed($0) }

    case let .keyPath(toChildState):
      return self.child
        .reduce(into: &state[keyPath: toChildState], action: childAction)
        .map { self.toChildAction.embed($0) }
    }
  }
}
