import CasePaths
import Combine
import SwiftUI
import XCTestDynamicOverlay

// MARK: - Deprecated after 0.54.1

extension WithViewStore where ViewState == Void, Content: View {
  @available(*, deprecated, message: "Use 'store.send(action)' directly on the 'Store' instead.")
  public init(
    _ store: Store<ViewState, ViewAction>,
    @ViewBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(store, removeDuplicates: ==, content: content, file: file, line: line)
  }
}

extension EffectPublisher {
  @available(*, deprecated, message: "Use 'Effect.merge([.cancel(id: …), …])' instead.")
  public static func cancel(ids: [AnyHashable]) -> Self {
    .merge(ids.map(EffectPublisher.cancel(id:)))
  }
}

// MARK: - Deprecated after 0.52.0

extension WithViewStore {
  @available(*, deprecated, renamed: "_printChanges(_:)")
  public func debug(_ prefix: String = "") -> Self {
    self._printChanges(prefix)
  }
}

extension EffectPublisher where Failure == Never {
  @available(iOS, deprecated: 9999, message: "Use 'Effect.run' and pass the action to 'send'.")
  @available(macOS, deprecated: 9999, message: "Use 'Effect.run' and pass the action to 'send'.")
  @available(tvOS, deprecated: 9999, message: "Use 'Effect.run' and pass the action to 'send'.")
  @available(watchOS, deprecated: 9999, message: "Use 'Effect.run' and pass the action to 'send'.")
  public static func task(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> Action,
    catch handler: (@Sendable (Error) async -> Action)? = nil,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    withEscapedDependencies { escaped in
      Self(
        operation: .run(priority) { send in
          await escaped.yield {
            do {
              try await send(operation())
            } catch is CancellationError {
              return
            } catch {
              guard let handler = handler else {
                #if DEBUG
                  var errorDump = ""
                  customDump(error, to: &errorDump, indent: 4)
                  runtimeWarn(
                    """
                    An "EffectTask.task" returned from "\(fileID):\(line)" threw an unhandled \
                    error. …

                    \(errorDump)

                    All non-cancellation errors must be explicitly handled via the "catch" \
                    parameter on "EffectTask.task", or via a "do" block.
                    """
                  )
                #endif
                return
              }
              await send(handler(error))
            }
          }
        }
      )
    }
  }

  @available(iOS, deprecated: 9999, message: "Use 'Effect.run' and ignore 'send' instead.")
  @available(macOS, deprecated: 9999, message: "Use 'Effect.run' and ignore 'send' instead.")
  @available(tvOS, deprecated: 9999, message: "Use 'Effect.run' and ignore 'send' instead.")
  @available(watchOS, deprecated: 9999, message: "Use 'Effect.run' and ignore 'send' instead.")
  public static func fireAndForget(
    priority: TaskPriority? = nil,
    _ work: @escaping @Sendable () async throws -> Void
  ) -> Self {
    Self.run(priority: priority) { _ in try? await work() }
  }
}

extension Store {
  @available(iOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(macOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(tvOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(watchOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  public convenience init<R: ReducerProtocol>(
    initialState: @autoclosure () -> R.State,
    reducer: R,
    prepareDependencies: ((inout DependencyValues) -> Void)? = nil
  ) where R.State == State, R.Action == Action {
    if let prepareDependencies = prepareDependencies {
      self.init(
        initialState: withDependencies(prepareDependencies) { initialState() },
        reducer: reducer.transformDependency(\.self, transform: prepareDependencies),
        mainThreadChecksEnabled: true
      )
    } else {
      self.init(
        initialState: initialState(),
        reducer: reducer,
        mainThreadChecksEnabled: true
      )
    }
  }
}

extension TestStore {
  @available(iOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(macOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(tvOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(watchOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  public convenience init<R: ReducerProtocol>(
    initialState: @autoclosure () -> State,
    reducer: R,
    prepareDependencies: (inout DependencyValues) -> Void = { _ in },
    file: StaticString = #file,
    line: UInt = #line
  )
  where
    R.State == State,
    R.Action == Action,
    State == ScopedState,
    State: Equatable,
    Action == ScopedAction,
    Environment == Void
  {
    self.init(
      initialState: initialState(),
      reducer: reducer,
      observe: { $0 },
      send: { $0 },
      prepareDependencies: prepareDependencies,
      file: file,
      line: line
    )
  }

  @available(iOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(macOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(tvOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(watchOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  public convenience init<R: ReducerProtocol>(
    initialState: @autoclosure () -> State,
    reducer: R,
    observe toScopedState: @escaping (State) -> ScopedState,
    prepareDependencies: (inout DependencyValues) -> Void = { _ in },
    file: StaticString = #file,
    line: UInt = #line
  )
  where
    R.State == State,
    R.Action == Action,
    ScopedState: Equatable,
    Action == ScopedAction,
    Environment == Void
  {
    self.init(
      initialState: initialState(),
      reducer: reducer,
      observe: toScopedState,
      send: { $0 },
      prepareDependencies: prepareDependencies,
      file: file,
      line: line
    )
  }

  @available(iOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(macOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(tvOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  @available(watchOS, deprecated: 9999, message: "Pass a closure as the reducer.")
  public convenience init<R: ReducerProtocol>(
    initialState: @autoclosure () -> State,
    reducer: R,
    observe toScopedState: @escaping (State) -> ScopedState,
    send fromScopedAction: @escaping (ScopedAction) -> Action,
    prepareDependencies: (inout DependencyValues) -> Void = { _ in },
    file: StaticString = #file,
    line: UInt = #line
  )
  where
    R.State == State,
    R.Action == Action,
    ScopedState: Equatable,
    Environment == Void
  {
    self.init(
      initialState: initialState(),
      reducer: { reducer },
      observe: toScopedState,
      send: fromScopedAction,
      withDependencies: prepareDependencies,
      file: file,
      line: line
    )
  }

  @available(*, deprecated, message: "State must be equatable to perform assertions.")
  public convenience init<R: ReducerProtocol>(
    initialState: @autoclosure () -> State,
    reducer: R,
    prepareDependencies: (inout DependencyValues) -> Void = { _ in },
    file: StaticString = #file,
    line: UInt = #line
  )
  where
    R.State == State,
    R.Action == Action,
    State == ScopedState,
    Action == ScopedAction,
    Environment == Void
  {
    self.init(
      initialState: initialState(),
      reducer: { reducer },
      withDependencies: prepareDependencies,
      file: file,
      line: line
    )
  }
}

extension Store {
  @available(
    *,
    deprecated,
    message:
      """
      'Store.scope' requires an explicit 'action' transform and is intended to be used to transform a store of a parent domain into a store of a child domain.

      When transforming store state into view state, use the 'observe' parameter when constructing a view store.
      """
  )
  public func scope<ChildState>(
    state toChildState: @escaping (State) -> ChildState
  ) -> Store<ChildState, Action> {
    self.scope(state: toChildState, action: { $0 })
  }
}

extension EffectPublisher {
  @available(
    *,
    deprecated,
    message:
      """
      Types defined for cancellation may be compiled out of release builds in Swift and are unsafe to use. Use a hashable value, instead, e.g. define a timer cancel identifier as 'enum CancelID { case timer }' and call 'Effect.cancellable(id: CancelID.timer)'.
      """
  )
  public func cancellable(id: Any.Type, cancelInFlight: Bool = false) -> Self {
    self.cancellable(id: ObjectIdentifier(id), cancelInFlight: cancelInFlight)
  }

  public static func cancel(id: Any.Type) -> Self {
    .cancel(id: ObjectIdentifier(id))
  }

  @available(
    *,
    deprecated,
    message:
      """
      Types defined for cancellation may be compiled out of release builds in Swift and are unsafe to use. Use a hashable value, instead, e.g. define a timer cancel identifier as 'enum CancelID { case timer }' and call 'Effect.cancel(id: CancelID.timer)'.
      """
  )
  public static func cancel(ids: [Any.Type]) -> Self {
    .merge(ids.map(EffectPublisher.cancel(id:)))
  }
}

@available(
  *,
  deprecated,
  message:
    """
    Types defined for cancellation may be compiled out of release builds in Swift and are unsafe to use. Use a hashable value, instead, e.g. define a timer cancel identifier as 'enum CancelID { case timer }' and call 'withTaskCancellation(id: CancelID.timer)'.
    """
)
public func withTaskCancellation<T: Sendable>(
  id: Any.Type,
  cancelInFlight: Bool = false,
  operation: @Sendable @escaping () async throws -> T
) async rethrows -> T {
  try await withTaskCancellation(
    id: ObjectIdentifier(id),
    cancelInFlight: cancelInFlight,
    operation: operation
  )
}

extension Task where Success == Never, Failure == Never {
  @available(
    *,
    deprecated,
    message:
      """
      Types defined for cancellation may be compiled out of release builds in Swift and are unsafe to use. Use a hashable value, instead, e.g. define a timer cancel identifier as 'enum CancelID { case timer }' and call 'Effect.cancel(id: CancelID.timer)'.
      """
  )
  public static func cancel(id: Any.Type) {
    self.cancel(id: ObjectIdentifier(id))
  }
}

// MARK: - Deprecated after 0.49.2

@available(
  *,
  deprecated,
  message: "Use 'ReducerBuilder<_, _>' with explicit 'State' and 'Action' generics, instead."
)
public typealias ReducerBuilderOf<R: ReducerProtocol> = ReducerBuilder<R.State, R.Action>

// NB: As of Swift 5.7, property wrapper deprecations are not diagnosed, so we may want to keep this
//     deprecation around for now:
//     https://github.com/apple/swift/issues/63139
@available(*, deprecated, renamed: "BindingState")
public typealias BindableState = BindingState

// MARK: - Deprecated after 0.47.2

extension ActorIsolated {
  @available(
    *,
    deprecated,
    message: "Use the non-async version of 'withValue'."
  )
  public func withValue<T: Sendable>(
    _ operation: @Sendable (inout Value) async throws -> T
  ) async rethrows -> T {
    var value = self.value
    defer { self.value = value }
    return try await operation(&value)
  }
}

// MARK: - Deprecated after 0.45.0:

@available(
  *,
  deprecated,
  message: "Pass 'TextState' to the 'SwiftUI.Text' initializer, instead, e.g., 'Text(textState)'."
)
extension TextState: View {
  public var body: some View {
    Text(self)
  }
}

// MARK: - Deprecated after 0.42.0:

/// This API has been deprecated in favor of ``ReducerProtocol``.
/// Read <doc:MigratingToTheReducerProtocol> for more information.
///
/// A type alias to ``AnyReducer`` for source compatibility. This alias will be removed.
@available(
  *,
  deprecated,
  renamed: "AnyReducer",
  message:
    """
    'Reducer' has been deprecated in favor of 'ReducerProtocol'.

    See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
    """
)
public typealias Reducer = AnyReducer

// MARK: - Deprecated after 0.41.0:

extension ViewStore {
  @available(*, deprecated, renamed: "ViewState")
  public typealias State = ViewState

  @available(*, deprecated, renamed: "ViewAction")
  public typealias Action = ViewAction
}

extension ReducerProtocol {
  @available(*, deprecated, renamed: "_printChanges")
  @warn_unqualified_access
  public func debug() -> _PrintChangesReducer<Self> {
    self._printChanges()
  }
}

extension ReducerBuilder {
  @_disfavoredOverload
  @available(
    *,
    deprecated,
    message:
      """
      Reducer bodies should return 'some ReducerProtocol<State, Action>' instead of 'Reduce<State, Action>'.
      """
  )
  @inlinable
  public static func buildFinalResult<R: ReducerProtocol>(_ reducer: R) -> Reduce<State, Action>
  where R.State == State, R.Action == Action {
    Reduce(reducer)
  }

  @_disfavoredOverload
  @inlinable
  public static func buildFinalResult(_ reducer: Reduce<State, Action>) -> Reduce<State, Action> {
    reducer
  }
}

// MARK: - Deprecated after 0.39.1:

extension WithViewStore {
  @available(*, deprecated, renamed: "ViewState")
  public typealias State = ViewState

  @available(*, deprecated, renamed: "ViewAction")
  public typealias Action = ViewAction
}

// MARK: - Deprecated after 0.39.0:

extension CaseLet {
  @available(*, deprecated, renamed: "EnumState")
  public typealias GlobalState = EnumState

  @available(*, deprecated, renamed: "EnumAction")
  public typealias GlobalAction = EnumAction

  @available(*, deprecated, renamed: "CaseState")
  public typealias LocalState = CaseState

  @available(*, deprecated, renamed: "CaseAction")
  public typealias LocalAction = CaseAction
}

extension TestStore {
  @available(*, deprecated, renamed: "ScopedState")
  public typealias LocalState = ScopedState

  @available(*, deprecated, renamed: "ScopedAction")
  public typealias LocalAction = ScopedAction
}

// MARK: - Deprecated after 0.38.2:

extension EffectPublisher {
  @available(*, deprecated)
  public var upstream: AnyPublisher<Action, Failure> {
    self.publisher
  }
}

extension EffectPublisher where Failure == Error {
  @_disfavoredOverload
  @available(
    *,
    deprecated,
    message: "Use the non-failing version of 'EffectTask.task'"
  )
  public static func task(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> Action
  ) -> Self {
    Deferred<Publishers.HandleEvents<PassthroughSubject<Action, Failure>>> {
      let subject = PassthroughSubject<Action, Failure>()
      let task = Task(priority: priority) { @MainActor in
        do {
          try Task.checkCancellation()
          let output = try await operation()
          try Task.checkCancellation()
          subject.send(output)
          subject.send(completion: .finished)
        } catch is CancellationError {
          subject.send(completion: .finished)
        } catch {
          subject.send(completion: .failure(error))
        }
      }
      return subject.handleEvents(receiveCancel: task.cancel)
    }
    .eraseToEffect()
  }
}

/// Initializes a store from an initial state, a reducer, and an environment, and the main thread
/// check is disabled for all interactions with this store.
///
/// - Parameters:
///   - initialState: The state to start the application in.
///   - reducer: The reducer that powers the business logic of the application.
///   - environment: The environment of dependencies for the application.
@available(
  *, deprecated,
  message:
    """
    If you use this initializer, please open a discussion on GitHub and let us know how: https://github.com/pointfreeco/swift-composable-architecture/discussions/new
    """
)
extension Store {
  public static func unchecked<Environment>(
    initialState: State,
    reducer: AnyReducer<State, Action, Environment>,
    environment: Environment
  ) -> Self {
    self.init(
      initialState: initialState,
      reducer: Reduce(reducer, environment: environment),
      mainThreadChecksEnabled: false
    )
  }
}

// MARK: - Deprecated after 0.38.0:

extension EffectPublisher {
  @available(iOS, deprecated: 9999, renamed: "unimplemented")
  @available(macOS, deprecated: 9999, renamed: "unimplemented")
  @available(tvOS, deprecated: 9999, renamed: "unimplemented")
  @available(watchOS, deprecated: 9999, renamed: "unimplemented")
  public static func failing(_ prefix: String) -> Self {
    self.unimplemented(prefix)
  }
}

// MARK: - Deprecated after 0.36.0:

extension ViewStore {
  @available(*, deprecated, renamed: "yield(while:)")
  @MainActor
  public func suspend(while predicate: @escaping (ViewState) -> Bool) async {
    await self.yield(while: predicate)
  }
}

// MARK: - Deprecated after 0.34.0:

extension EffectPublisher {
  @available(
    *,
    deprecated,
    message:
      """
      Using a variadic list is no longer supported. Use an array of identifiers instead. For more \
      on this change, see: https://github.com/pointfreeco/swift-composable-architecture/pull/1041
      """
  )
  @_disfavoredOverload
  public static func cancel(ids: AnyHashable...) -> Self {
    .cancel(ids: ids)
  }
}

// MARK: - Deprecated after 0.31.0:

extension AnyReducer {
  @available(
    *,
    deprecated,
    message: "'pullback' no longer takes a 'breakpointOnNil' argument"
  )
  public func pullback<ParentState, ParentAction, ParentEnvironment>(
    state toChildState: CasePath<ParentState, State>,
    action toChildAction: CasePath<ParentAction, Action>,
    environment toChildEnvironment: @escaping (ParentEnvironment) -> Environment,
    breakpointOnNil: Bool,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> AnyReducer<ParentState, ParentAction, ParentEnvironment> {
    self.pullback(
      state: toChildState,
      action: toChildAction,
      environment: toChildEnvironment,
      file: file,
      line: line
    )
  }

  @available(
    *,
    deprecated,
    message: "'optional' no longer takes a 'breakpointOnNil' argument"
  )
  public func optional(
    breakpointOnNil: Bool,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> AnyReducer<State?, Action, Environment> {
    self.optional(file: file, line: line)
  }

  @available(
    *,
    deprecated,
    message: "'forEach' no longer takes a 'breakpointOnNil' argument"
  )
  public func forEach<ParentState, ParentAction, ParentEnvironment, ID>(
    state toElementsState: WritableKeyPath<ParentState, IdentifiedArray<ID, State>>,
    action toElementAction: CasePath<ParentAction, (ID, Action)>,
    environment toElementEnvironment: @escaping (ParentEnvironment) -> Environment,
    breakpointOnNil: Bool,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> AnyReducer<ParentState, ParentAction, ParentEnvironment> {
    self.forEach(
      state: toElementsState,
      action: toElementAction,
      environment: toElementEnvironment,
      file: file,
      line: line
    )
  }

  @available(
    *,
    deprecated,
    message: "'forEach' no longer takes a 'breakpointOnNil' argument"
  )
  public func forEach<ParentState, ParentAction, ParentEnvironment, Key>(
    state toElementsState: WritableKeyPath<ParentState, [Key: State]>,
    action toElementAction: CasePath<ParentAction, (Key, Action)>,
    environment toElementEnvironment: @escaping (ParentEnvironment) -> Environment,
    breakpointOnNil: Bool,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> AnyReducer<ParentState, ParentAction, ParentEnvironment> {
    self.forEach(
      state: toElementsState,
      action: toElementAction,
      environment: toElementEnvironment,
      file: file,
      line: line
    )
  }
}

// MARK: - Deprecated after 0.29.0:

extension TestStore where ScopedState: Equatable, Action: Equatable {
  @available(
    *, deprecated, message: "Use 'TestStore.send' and 'TestStore.receive' directly, instead."
  )
  public func assert(
    _ steps: Step...,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    assert(steps, file: file, line: line)
  }

  @available(
    *, deprecated, message: "Use 'TestStore.send' and 'TestStore.receive' directly, instead."
  )
  public func assert(
    _ steps: [Step],
    file: StaticString = #file,
    line: UInt = #line
  ) {

    func assert(step: Step) {
      switch step.type {
      case let .send(action, updateStateToExpectedResult):
        self.send(action, assert: updateStateToExpectedResult, file: step.file, line: step.line)

      case let .receive(expectedAction, updateStateToExpectedResult):
        self.receive(
          expectedAction, assert: updateStateToExpectedResult, file: step.file, line: step.line
        )

      case let .environment(work):
        if !self.reducer.receivedActions.isEmpty {
          var actions = ""
          customDump(self.reducer.receivedActions.map(\.action), to: &actions)
          XCTFail(
            """
            Must handle \(self.reducer.receivedActions.count) received \
            action\(self.reducer.receivedActions.count == 1 ? "" : "s") before performing this \
            work: …

            Unhandled actions: \(actions)
            """,
            file: step.file, line: step.line
          )
        }
        do {
          try work(&self.environment)
        } catch {
          XCTFail("Threw error: \(error)", file: step.file, line: step.line)
        }

      case let .do(work):
        if !self.reducer.receivedActions.isEmpty {
          var actions = ""
          customDump(self.reducer.receivedActions.map(\.action), to: &actions)
          XCTFail(
            """
            Must handle \(self.reducer.receivedActions.count) received \
            action\(self.reducer.receivedActions.count == 1 ? "" : "s") before performing this \
            work: …

            Unhandled actions: \(actions)
            """,
            file: step.file, line: step.line
          )
        }
        do {
          try work()
        } catch {
          XCTFail("Threw error: \(error)", file: step.file, line: step.line)
        }

      case let .sequence(subSteps):
        subSteps.forEach(assert(step:))
      }
    }

    steps.forEach(assert(step:))

    self.completed()
  }

  public struct Step {
    fileprivate let type: StepType
    fileprivate let file: StaticString
    fileprivate let line: UInt

    private init(
      _ type: StepType,
      file: StaticString = #file,
      line: UInt = #line
    ) {
      self.type = type
      self.file = file
      self.line = line
    }

    @available(*, deprecated, message: "Call 'TestStore.send' directly, instead.")
    public static func send(
      _ action: ScopedAction,
      file: StaticString = #file,
      line: UInt = #line,
      _ update: ((inout ScopedState) throws -> Void)? = nil
    ) -> Step {
      Step(.send(action, update), file: file, line: line)
    }

    @available(*, deprecated, message: "Call 'TestStore.receive' directly, instead.")
    public static func receive(
      _ action: Action,
      file: StaticString = #file,
      line: UInt = #line,
      _ update: ((inout ScopedState) throws -> Void)? = nil
    ) -> Step {
      Step(.receive(action, update), file: file, line: line)
    }

    @available(*, deprecated, message: "Mutate 'TestStore.environment' directly, instead.")
    public static func environment(
      file: StaticString = #file,
      line: UInt = #line,
      _ update: @escaping (inout Environment) throws -> Void
    ) -> Step {
      Step(.environment(update), file: file, line: line)
    }

    @available(*, deprecated, message: "Perform this work directly in your test, instead.")
    public static func `do`(
      file: StaticString = #file,
      line: UInt = #line,
      _ work: @escaping () throws -> Void
    ) -> Step {
      Step(.do(work), file: file, line: line)
    }

    @available(*, deprecated, message: "Perform this work directly in your test, instead.")
    public static func sequence(
      _ steps: [Step],
      file: StaticString = #file,
      line: UInt = #line
    ) -> Step {
      Step(.sequence(steps), file: file, line: line)
    }

    @available(*, deprecated, message: "Perform this work directly in your test, instead.")
    public static func sequence(
      _ steps: Step...,
      file: StaticString = #file,
      line: UInt = #line
    ) -> Step {
      Step(.sequence(steps), file: file, line: line)
    }

    fileprivate indirect enum StepType {
      case send(ScopedAction, ((inout ScopedState) throws -> Void)?)
      case receive(Action, ((inout ScopedState) throws -> Void)?)
      case environment((inout Environment) throws -> Void)
      case `do`(() throws -> Void)
      case sequence([Step])
    }
  }
}

// MARK: - Deprecated after 0.27.1:

@available(iOS 13, *)
@available(macOS 12, *)
@available(tvOS 13, *)
@available(watchOS 6, *)
@available(*, deprecated, renamed: "ConfirmationDialogState")
public typealias ActionSheetState = ConfirmationDialogState

extension View {
  @available(iOS 13, *)
  @available(macOS 12, *)
  @available(tvOS 13, *)
  @available(watchOS 6, *)
  @available(*, deprecated, renamed: "confirmationDialog")
  public func actionSheet<Action>(
    _ store: Store<ConfirmationDialogState<Action>?, Action>,
    dismiss: Action
  ) -> some View {
    self.confirmationDialog(store, dismiss: dismiss)
  }
}

extension Store {
  @available(
    *, deprecated,
    message:
      """
      If you use this method, please open a discussion on GitHub and let us know how: \
      https://github.com/pointfreeco/swift-composable-architecture/discussions/new
      """
  )
  public func publisherScope<P: Publisher, ChildState, ChildAction>(
    state toChildState: @escaping (AnyPublisher<State, Never>) -> P,
    action fromChildAction: @escaping (ChildAction) -> Action
  ) -> AnyPublisher<Store<ChildState, ChildAction>, Never>
  where P.Output == ChildState, P.Failure == Never {

    func extractChildState(_ state: State) -> ChildState? {
      var childState: ChildState?
      _ = toChildState(Just(state).eraseToAnyPublisher())
        .sink { childState = $0 }
      return childState
    }

    return toChildState(self.state.eraseToAnyPublisher())
      .map { childState in
        let childStore = Store<ChildState, ChildAction>(
          initialState: childState,
          reducer: .init { childState, childAction, _ in
            let task = self.send(fromChildAction(childAction), originatingFrom: nil)
            childState = extractChildState(self.state.value) ?? childState
            if let task = task {
              return .run { _ in await task.cancellableValue }
            } else {
              return .none
            }
          },
          environment: ()
        )

        childStore.parentCancellable = self.state
          .sink { [weak childStore] state in
            guard let childStore = childStore else { return }
            childStore.state.value = extractChildState(state) ?? childStore.state.value
          }
        return childStore
      }
      .eraseToAnyPublisher()
  }

  @available(
    *, deprecated,
    message:
      """
      If you use this method, please open a discussion on GitHub and let us know how: \
      https://github.com/pointfreeco/swift-composable-architecture/discussions/new
      """
  )
  public func publisherScope<P: Publisher, ChildState>(
    state toChildState: @escaping (AnyPublisher<State, Never>) -> P
  ) -> AnyPublisher<Store<ChildState, Action>, Never>
  where P.Output == ChildState, P.Failure == Never {
    self.publisherScope(state: toChildState, action: { $0 })
  }
}

// MARK: - Deprecated after 0.25.0:

extension BindingAction {
  @available(
    *, deprecated,
    message:
      """
      For improved safety, bindable properties must now be wrapped explicitly in 'BindingState', \
      and accessed via key paths to that 'BindingState', like '\\.$value'
      """
  )
  public static func set<Value: Equatable & Sendable>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self {
    .init(
      keyPath: keyPath,
      set: { $0[keyPath: keyPath] = value },
      value: AnySendable(value),
      valueIsEqualTo: { $0 as? Value == value }
    )
  }

  @available(
    *, deprecated,
    message:
      """
      For improved safety, bindable properties must now be wrapped explicitly in 'BindingState', \
      and accessed via key paths to that 'BindingState', like '\\.$value'
      """
  )
  public static func ~= <Value>(
    keyPath: WritableKeyPath<Root, Value>,
    bindingAction: Self
  ) -> Bool {
    keyPath == bindingAction.keyPath
  }
}

extension AnyReducer {
  @available(
    *, deprecated,
    message:
      """
      'Reducer.binding()' no longer takes an explicit extract function and instead the reducer's \
      'Action' type must conform to 'BindableAction'
      """
  )
  public func binding(action toBindingAction: @escaping (Action) -> BindingAction<State>?) -> Self {
    Self { state, action, environment in
      toBindingAction(action)?.set(&state)
      return self.run(&state, action, environment)
    }
  }
}

extension ViewStore {
  @available(
    *, deprecated,
    message:
      """
      For improved safety, bindable properties must now be wrapped explicitly in 'BindingState'. \
      Bindings are now derived via 'ViewStore.binding' with a key path to that 'BindingState' \
      (for example, 'viewStore.binding(\\.$value)'). For dynamic member lookup to be available, \
      the view store's 'Action' type must also conform to 'BindableAction'.
      """
  )
  @MainActor
  public func binding<Value: Equatable>(
    keyPath: WritableKeyPath<ViewState, Value>,
    send action: @escaping (BindingAction<ViewState>) -> ViewAction
  ) -> Binding<Value> {
    self.binding(
      get: { $0[keyPath: keyPath] },
      send: { action(.set(keyPath, $0)) }
    )
  }
}

// MARK: - Deprecated after 0.20.0:

extension AnyReducer {
  @available(*, deprecated, message: "Use the 'IdentifiedArray'-based version, instead.")
  public func forEach<ParentState, ParentAction, ParentEnvironment>(
    state toElementsState: WritableKeyPath<ParentState, [State]>,
    action toElementAction: CasePath<ParentAction, (Int, Action)>,
    environment toElementEnvironment: @escaping (ParentEnvironment) -> Environment,
    breakpointOnNil: Bool = true,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> AnyReducer<ParentState, ParentAction, ParentEnvironment> {
    .init { parentState, parentAction, parentEnvironment in
      guard let (index, action) = toElementAction.extract(from: parentAction) else {
        return .none
      }
      if index >= parentState[keyPath: toElementsState].endIndex {
        runtimeWarn(
          """
          A "forEach" reducer at "\(fileID):\(line)" received an action when state contained no \
          element at that index. …

            Action:
              \(debugCaseOutput(action))
            Index:
              \(index)

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • This "forEach" reducer was combined with or run from another reducer that removed \
          the element at this index when it handled this action. To fix this make sure that this \
          "forEach" reducer is run before any other reducers that can move or remove elements \
          from state. This ensures that "forEach" reducers can handle their actions for the \
          element at the intended index.

          • An in-flight effect emitted this action while state contained no element at this \
          index. While it may be perfectly reasonable to ignore this action, you may want to \
          cancel the associated effect when moving or removing an element. If your "forEach" \
          reducer returns any long-living effects, you should use the identifier-based "forEach" \
          instead.

          • This action was sent to the store while its state contained no element at this index \
          To fix this make sure that actions for this reducer can only be sent to a view store \
          when its state contains an element at this index. In SwiftUI applications, use \
          "ForEachStore".
          """
        )
        return .none
      }
      return self.run(
        &parentState[keyPath: toElementsState][index],
        action,
        toElementEnvironment(parentEnvironment)
      )
      .map { toElementAction.embed((index, $0)) }
    }
  }
}

extension ForEachStore {
  @available(*, deprecated, message: "Use the 'IdentifiedArray'-based version, instead.")
  public init<EachContent>(
    _ store: Store<Data, (Data.Index, EachAction)>,
    id: KeyPath<EachState, ID>,
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == [EachState],
    Content == WithViewStore<
      [ID], (Data.Index, EachAction), ForEach<[(offset: Int, element: ID)], ID, EachContent>
    >
  {
    let data = store.state.value
    self.data = data
    self.content = WithViewStore(store, observe: { $0.map { $0[keyPath: id] } }) { viewStore in
      ForEach(Array(viewStore.state.enumerated()), id: \.element) { index, _ in
        content(
          store.scope(
            state: { index < $0.endIndex ? $0[index] : data[index] },
            action: { (index, $0) }
          )
        )
      }
    }
  }

  @available(*, deprecated, message: "Use the 'IdentifiedArray'-based version, instead.")
  public init<EachContent>(
    _ store: Store<Data, (Data.Index, EachAction)>,
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == [EachState],
    Content == WithViewStore<
      [ID], (Data.Index, EachAction), ForEach<[(offset: Int, element: ID)], ID, EachContent>
    >,
    EachState: Identifiable,
    EachState.ID == ID
  {
    self.init(store, id: \.id, content: content)
  }
}
