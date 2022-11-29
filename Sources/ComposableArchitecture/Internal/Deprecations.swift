import CasePaths
import Combine
import SwiftUI
import XCTestDynamicOverlay

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
  public func debug() -> _PrintChangesReducer<Self> {
    self._printChanges()
  }
}

#if swift(>=5.7)
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
#endif

// MARK: - Deprecated after 0.40.0:

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension WithViewStore: AccessibilityRotorContent where Content: AccessibilityRotorContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute accessibility rotor content from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from an accessibility rotor content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<ViewState, ViewAction>) ->
      Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store,
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension WithViewStore where ViewState: Equatable, Content: AccessibilityRotorContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute accessibility rotor content from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from an accessibility rotor content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<ViewState, ViewAction>) ->
      Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(store, removeDuplicates: ==, content: content, file: file, line: line)
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension WithViewStore where ViewState == Void, Content: AccessibilityRotorContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute accessibility rotor content from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from an accessibility rotor content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<ViewState, ViewAction>) ->
      Content
  ) {
    self.init(store, removeDuplicates: ==, content: content, file: file, line: line)
  }
}

@available(iOS 14, macOS 11, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension WithViewStore: Commands where Content: Commands {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute commands from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from a command builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    @CommandsBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store,
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

@available(iOS 14, macOS 11, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension WithViewStore where ViewState: Equatable, Content: Commands {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute commands from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from a command builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    @CommandsBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(store, removeDuplicates: ==, content: content, file: file, line: line)
  }
}

@available(iOS 14, macOS 11, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension WithViewStore where ViewState == Void, Content: Commands {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute commands from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from a command builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @CommandsBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, content: content, file: file, line: line)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore: Scene where Content: Scene {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute scenes from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from a scene builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    @SceneBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store,
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore where ViewState: Equatable, Content: Scene {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute scenes from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from a scene builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    @SceneBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(store, removeDuplicates: ==, content: content, file: file, line: line)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore where ViewState == Void, Content: Scene {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute scenes from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from a scene builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, content: content, file: file, line: line)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore: ToolbarContent where Content: ToolbarContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute toolbar content from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from a toolbar content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ToolbarContentBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content
  ) {
    self.init(
      store: store,
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore where ViewState: Equatable, Content: ToolbarContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute toolbar content from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from a toolbar content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ToolbarContentBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore where ViewState == Void, Content: ToolbarContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute toolbar content from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    *,
    deprecated,
    message:
      """
      For compiler performance, using "WithViewStore" from a toolbar content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

      See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
      """
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ToolbarContentBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
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
    If you use this initializer, please open a discussion on GitHub and let us know how: \
    https://github.com/pointfreeco/swift-composable-architecture/discussions/new
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
  @available(iOS, deprecated: 9999.0, renamed: "unimplemented")
  @available(macOS, deprecated: 9999.0, renamed: "unimplemented")
  @available(tvOS, deprecated: 9999.0, renamed: "unimplemented")
  @available(watchOS, deprecated: 9999.0, renamed: "unimplemented")
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
  ) -> AnyReducer<
    State?, Action, Environment
  > {
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
            let task = self.send(fromChildAction(childAction))
            childState = extractChildState(self.state.value) ?? childState
            if let task = task {
              return .fireAndForget { await task.cancellableValue }
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

extension ViewStore where ViewAction: BindableAction, ViewAction.State == ViewState {
  @available(
    *, deprecated,
    message:
      """
      Dynamic member lookup is no longer supported for bindable state. Instead of dot-chaining on \
      the view store, e.g. 'viewStore.$value', invoke the 'binding' method on view store with a \
      key path to the value, e.g. 'viewStore.binding(\\.$value)'. For more on this change, see: \
      https://github.com/pointfreeco/swift-composable-architecture/pull/810
      """
  )
  @MainActor
  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<ViewState, BindableState<Value>>
  ) -> Binding<Value> {
    self.binding(
      get: { $0[keyPath: keyPath].wrappedValue },
      send: { .binding(.set(keyPath, $0)) }
    )
  }
}

// MARK: - Deprecated after 0.25.0:

extension BindingAction {
  @available(
    *, deprecated,
    message:
      """
      For improved safety, bindable properties must now be wrapped explicitly in 'BindableState', \
      and accessed via key paths to that 'BindableState', like '\\.$value'
      """
  )
  public static func set<Value: Equatable>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self {
    .init(
      keyPath: keyPath,
      set: { $0[keyPath: keyPath] = value },
      value: value,
      valueIsEqualTo: { $0 as? Value == value }
    )
  }

  @available(
    *, deprecated,
    message:
      """
      For improved safety, bindable properties must now be wrapped explicitly in 'BindableState', \
      and accessed via key paths to that 'BindableState', like '\\.$value'
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
      For improved safety, bindable properties must now be wrapped explicitly in 'BindableState'. \
      Bindings are now derived via 'ViewStore.binding' with a key path to that 'BindableState' \
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
          """,
          file: file,
          line: line
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
    self.content = WithViewStore(store.scope(state: { $0.map { $0[keyPath: id] } })) { viewStore in
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
