import CasePaths
import Combine

/// A reducer describes how to evolve the current state of an application to the next state, given
/// an action, and describes what ``Effect``s should be executed later by the store, if any.
///
/// Reducers have 3 generics:
///
///   * `State`: A type that holds the current state of the application.
///   * `Action`: A type that holds all possible actions that cause the state of the application to
///     change.
///   * `Environment`: A type that holds all dependencies needed in order to produce ``Effect``s,
///     such as API clients, analytics clients, random number generators, etc.
///
/// > Important: The thread on which effects output is important. An effect's output is immediately
///   sent back into the store, and ``Store`` is not thread safe. This means all effects must
///   receive values on the same thread, **and** if the ``Store`` is being used to drive UI then all
///   output must be on the main thread. You can use the `Publisher` method `receive(on:)` for make
///   the effect output its values on the thread of your choice.
/// >
/// > This is only an issue if using the Combine interface of ``Effect`` as mentioned above. If you
///   you are only using Swift's concurrency tools and the `.task`, `.run` and `.fireAndForget`
///   functions on ``Effect``, then the threading is automatically handled for you.
public struct Reducer<State, Action, Environment> {
  private let reducer: (inout State, Action, Environment) -> Effect<Action, Never>

  /// Initializes a reducer from a simple reducer function signature.
  ///
  /// The reducer takes three arguments: state, action and environment. The state is `inout` so that
  /// you can make any changes to it directly inline. The reducer must return an effect, which
  /// typically would be constructed by using the dependencies inside the `environment` value. If
  /// no effect needs to be executed, a ``Effect/none`` effect can be returned.
  ///
  /// For example:
  ///
  /// ```swift
  /// struct MyState { var count = 0, text = "" }
  /// enum MyAction { case buttonTapped, textChanged(String) }
  /// struct MyEnvironment { var analyticsClient: AnalyticsClient }
  ///
  /// let myReducer = Reducer<MyState, MyAction, MyEnvironment> { state, action, environment in
  ///   switch action {
  ///   case .buttonTapped:
  ///     state.count += 1
  ///     return environment.analyticsClient.track("Button Tapped")
  ///
  ///   case .textChanged(let text):
  ///     state.text = text
  ///     return .none
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter reducer: A function signature that takes state, action and
  ///   environment.
  public init(_ reducer: @escaping (inout State, Action, Environment) -> Effect<Action, Never>) {
    self.reducer = reducer
  }

  /// A reducer that performs no state mutations and returns no effects.
  public static var empty: Reducer {
    Self { _, _, _ in .none }
  }

  /// Combines many reducers into a single one by running each one on state in order, and merging
  /// all of the effects.
  ///
  /// It is important to note that the order of combining reducers matter. Combining `reducerA` with
  /// `reducerB` is not necessarily the same as combining `reducerB` with `reducerA`.
  ///
  /// This can become an issue when working with reducers that have overlapping domains. For
  /// example, if `reducerA` embeds the domain of `reducerB` and reacts to its actions or modifies
  /// its state, it can make a difference if `reducerA` chooses to modify `reducerB`'s state
  /// _before_ or _after_ `reducerB` runs.
  ///
  /// This is perhaps most easily seen when working with ``optional(file:fileID:line:)`` reducers,
  /// where the parent domain may listen to the child domain and `nil` out its state. If the parent
  /// reducer runs before the child reducer, then the child reducer will not be able to react to its
  /// own action.
  ///
  /// Similar can be said for a ``forEach(state:action:environment:file:fileID:line:)-n7qj``
  /// reducer. If the parent domain modifies the child collection by moving, removing, or modifying
  /// an element before the `forEach` reducer runs, the `forEach` reducer may perform its action
  /// against the wrong element, an element that no longer exists, or an element in an unexpected
  /// state.
  ///
  /// Running a parent reducer before a child reducer can be considered an application logic
  /// error, and can produce assertion failures. So you should almost always combine reducers in
  /// order from child to parent domain.
  ///
  /// Here is an example of how you should combine an ``optional(file:fileID:line:)`` reducer with a
  /// parent domain:
  ///
  /// ```swift
  /// let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  ///   // Combined before parent so that it can react to `.dismiss` while state is non-`nil`.
  ///   childReducer.optional().pullback(
  ///     state: \.child,
  ///     action: /ParentAction.child,
  ///     environment: { $0.child }
  ///   ),
  ///   // Combined after child so that it can `nil` out child state upon `.child(.dismiss)`.
  ///   Reducer { state, action, environment in
  ///     switch action
  ///     case .child(.dismiss):
  ///       state.child = nil
  ///       return .none
  ///     ...
  ///     }
  ///   },
  /// )
  /// ```
  ///
  /// - Parameter reducers: A list of reducers.
  /// - Returns: A single reducer.
  public static func combine(_ reducers: Self...) -> Self {
    .combine(reducers)
  }

  /// Combines many reducers into a single one by running each one on state in order, and merging
  /// all of the effects.
  ///
  /// This method is identical to ``Reducer/combine(_:)-994ak`` except that it takes an array
  /// of reducers instead of a variadic list. See the documentation on
  /// ``Reducer/combine(_:)-994ak`` for more information about what this method does.
  ///
  /// - Parameter reducers: An array of reducers.
  /// - Returns: A single reducer.
  public static func combine(_ reducers: [Self]) -> Self {
    Self { value, action, environment in
      .merge(reducers.map { $0.reducer(&value, action, environment) })
    }
  }

  /// Combines the receiving reducer with one other reducer, running the second after the first and
  /// merging all of the effects.
  ///
  /// This method is identical to ``Reducer/combine(_:)-994ak`` except that it combines the
  /// receiver with a single other reducer rather than combining a whole list of reducers. See the
  /// documentation on ``Reducer/combine(_:)-994ak`` for more information about what this method
  /// does.
  ///
  /// - Parameter other: Another reducer.
  /// - Returns: A single reducer.
  public func combined(with other: Self) -> Self {
    .combine(self, other)
  }

  /// Transforms a reducer that works on child state, action, and environment into one that works on
  /// parent state, action and environment. It accomplishes this by providing 3 transformations to
  /// the method:
  ///
  ///   * A writable key path that can get/set a piece of child state from the parent state.
  ///   * A case path that can extract/embed a child action into a parent action.
  ///   * A function that can transform the parent environment into a child environment.
  ///
  /// This operation is important for breaking down large reducers into small ones. When used with
  /// the ``combine(_:)-1ern2`` operator you can define many reducers that work on small pieces of
  /// domain, and then _pull them back_ and _combine_ them into one big reducer that works on a
  /// large domain.
  ///
  ///    ```swift
  ///     // Parent domain that holds a child domain:
  ///     struct AppState { var settings: SettingsState, /* rest of state */ }
  ///     enum AppAction { case settings(SettingsAction), /* other actions */ }
  ///     struct AppEnvironment { var settings: SettingsEnvironment, /* rest of dependencies */ }
  ///
  ///     // A reducer that works on the child domain:
  ///     let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment> { ... }
  ///
  ///     // Pullback the settings reducer so that it works on all of the app domain:
  ///     let appReducer: Reducer<AppState, AppAction, AppEnvironment> = .combine(
  ///       settingsReducer.pullback(
  ///         state: \.settings,
  ///         action: /AppAction.settings,
  ///         environment: { $0.settings }
  ///       ),
  ///
  ///       /* other reducers */
  ///     )
  ///    ```
  ///
  /// - Parameters:
  ///   - toChildState: A key path that can get/set `State` inside `ParentState`.
  ///   - toChildAction: A case path that can extract/embed `Action` from `ParentAction`.
  ///   - toChildEnvironment: A function that transforms `ParentEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `ParentState`, `ParentAction`, `ParentEnvironment`.
  public func pullback<ParentState, ParentAction, ParentEnvironment>(
    state toChildState: WritableKeyPath<ParentState, State>,
    action toChildAction: CasePath<ParentAction, Action>,
    environment toChildEnvironment: @escaping (ParentEnvironment) -> Environment
  ) -> Reducer<ParentState, ParentAction, ParentEnvironment> {
    .init { parentState, parentAction, parentEnvironment in
      guard let childAction = toChildAction.extract(from: parentAction) else { return .none }
      return self.reducer(
        &parentState[keyPath: toChildState],
        childAction,
        toChildEnvironment(parentEnvironment)
      )
      .map(toChildAction.embed)
    }
  }

  /// Transforms a reducer that works on child state, action, and environment into one that works on
  /// parent state, action and environment.
  ///
  /// It accomplishes this by providing 3 transformations to the method:
  ///
  ///   * A case path that can extract/embed a piece of child state from the parent state, which is
  ///     typically an enum.
  ///   * A case path that can extract/embed a child action into a parent action.
  ///   * A function that can transform the parent environment into a child environment.
  ///
  /// This overload of ``pullback(state:action:environment:)`` differs from the other in that it
  /// takes a `CasePath` transformation for the state instead of a `WritableKeyPath`. This makes it
  /// perfect for working on enum state as opposed to struct state. In particular, you can use this
  /// operator to pullback a reducer that operates on a single case of some state enum to work on
  /// the entire state enum.
  ///
  /// When used with the ``combine(_:)-994ak`` operator you can define many reducers that work each
  /// case of the state enum, and then _pull them back_ and _combine_ them into one big reducer that
  /// works on a large domain.
  ///
  /// ```swift
  /// // Parent domain that holds a child domain:
  /// enum AppState { case loggedIn(LoggedInState), /* rest of state */ }
  /// enum AppAction { case loggedIn(LoggedInAction), /* other actions */ }
  /// struct AppEnvironment { var loggedIn: LoggedInEnvironment, /* rest of dependencies */ }
  ///
  /// // A reducer that works on the child domain:
  /// let loggedInReducer = Reducer<LoggedInState, LoggedInAction, LoggedInEnvironment> { ... }
  ///
  /// // Pullback the logged-in reducer so that it works on all of the app domain:
  /// let appReducer: Reducer<AppState, AppAction, AppEnvironment> = .combine(
  ///   loggedInReducer.pullback(
  ///     state: /AppState.loggedIn,
  ///     action: /AppAction.loggedIn,
  ///     environment: { $0.loggedIn }
  ///   ),
  ///
  ///   /* other reducers */
  /// )
  /// ```
  ///
  /// Take care when combining a child reducer for a particular case of enum state into its parent
  /// domain. A child reducer cannot process actions in its domain if it fails to extract its
  /// corresponding state. If a child action is sent to a reducer when its state is unavailable, it
  /// is generally considered a logic error, and a runtime warning will be logged. There are a few
  /// ways in which these errors can sneak into a code base:
  ///
  ///   * A parent reducer sets child state to a different case when processing a child action and
  ///     runs _before_ the child reducer:
  ///
  ///     ```swift
  ///     let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  ///       // When combining reducers, the parent reducer runs first
  ///       Reducer { state, action, environment in
  ///         switch action {
  ///         case .child(.didDisappear):
  ///           // And `nil`s out child state when processing a child action
  ///           state.child = .anotherChild(AnotherChildState())
  ///           return .none
  ///         ...
  ///         }
  ///       },
  ///       // Before the child reducer runs
  ///       childReducer.pullback(state: /ParentState.child, ...)
  ///     )
  ///
  ///     let childReducer = Reducer<
  ///       ChildState, ChildAction, ChildEnvironment
  ///     > { state, action environment in
  ///       case .didDisappear:
  ///         // This action is never received here because child state cannot be extracted
  ///       ...
  ///     }
  ///     ```
  ///
  ///     To ensure that a child reducer can process any action that a parent may use to change its
  ///     state, combine it _before_ the parent:
  ///
  ///     ```swift
  ///     let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  ///       // The child runs first
  ///       childReducer.pullback(state: /ParentState.child, ...),
  ///       // The parent runs after
  ///       Reducer { state, action, environment in
  ///         ...
  ///       }
  ///     )
  ///     ```
  ///
  ///   * A child effect feeds a child action back into the store when child state is unavailable:
  ///
  ///     ```swift
  ///     let childReducer = Reducer<
  ///       ChildState, ChildAction, ChildEnvironment
  ///     > { state, action environment in
  ///       switch action {
  ///       case .onAppear:
  ///         // An effect may want to later feed a result back to the child domain in an action
  ///         return environment.apiClient
  ///           .request()
  ///           .map(ChildAction.response)
  ///
  ///       case let .response(response):
  ///         // But the child cannot process this action if its state is unavailable
  ///       ...
  ///       }
  ///     }
  ///     ```
  ///
  ///     It is perfectly reasonable to ignore the result of an effect when child state is `nil`,
  ///     for example one-off effects that you don't want to cancel. However, many long-living
  ///     effects _should_ be explicitly canceled when tearing down a child domain:
  ///
  ///     ```swift
  ///     let childReducer = Reducer<
  ///       ChildState, ChildAction, ChildEnvironment
  ///     > { state, action environment in
  ///       enum MotionID {}
  ///
  ///       switch action {
  ///       case .onAppear:
  ///         // Mark long-living effects that shouldn't outlive their domain cancellable
  ///         return environment.motionClient
  ///           .start()
  ///           .map(ChildAction.motion)
  ///           .cancellable(id: MotionID.self)
  ///
  ///       case .onDisappear:
  ///         // And explicitly cancel them when the domain is torn down
  ///         return .cancel(id: MotionID.self)
  ///       ...
  ///       }
  ///     }
  ///     ```
  ///
  ///   * A view store sends a child action when child state is `nil`:
  ///
  ///     ```swift
  ///     WithViewStore(self.parentStore) { parentViewStore in
  ///       // If child state is `nil`, it cannot process this action.
  ///       Button("Child Action") { parentViewStore.send(.child(.action)) }
  ///       ...
  ///     }
  ///     ```
  ///
  ///     Use ``Store/scope(state:action:)`` with ``SwitchStore`` to ensure that views can only send
  ///     child actions when the child domain is available.
  ///
  ///     ```swift
  ///     SwitchStore(self.parentStore) {
  ///       CaseLet(state: /ParentState.child, action: ParentAction.child) { childStore in
  ///         // This destination only appears when child state matches
  ///         WithViewStore(childStore) { childViewStore in
  ///           // So this action can only be sent when child state is available
  ///           Button("Child Action") { childViewStore.send(.action) }
  ///         }
  ///       }
  ///       ...
  ///     }
  ///     ```
  ///
  /// - See also: ``SwitchStore``, a SwiftUI helper for transforming a store on enum state into
  ///   stores on each case of the enum.
  ///
  /// - Parameters:
  ///   - toChildState: A case path that can extract/embed `State` from `ParentState`.
  ///   - toChildAction: A case path that can extract/embed `Action` from `ParentAction`.
  ///   - toChildEnvironment: A function that transforms `ParentEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `ParentState`, `ParentAction`, `ParentEnvironment`.
  public func pullback<ParentState, ParentAction, ParentEnvironment>(
    state toChildState: CasePath<ParentState, State>,
    action toChildAction: CasePath<ParentAction, Action>,
    environment toChildEnvironment: @escaping (ParentEnvironment) -> Environment,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<ParentState, ParentAction, ParentEnvironment> {
    .init { parentState, parentAction, parentEnvironment in
      guard let childAction = toChildAction.extract(from: parentAction) else { return .none }

      guard var childState = toChildState.extract(from: parentState) else {
        runtimeWarning(
          """
          A reducer pulled back from "%@:%d" received an action when child state was \
          unavailable. …

            Action:
              %@

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • The reducer for a particular case of state was combined with or run from another \
          reducer that set "%@" to another case before the reducer ran. Combine or run \
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
            "\(State.self)",
          ],
          file: file,
          line: line
        )
        return .none
      }
      defer { parentState = toChildState.embed(childState) }

      let effects = self.run(
        &childState,
        childAction,
        toChildEnvironment(parentEnvironment)
      )
      .map(toChildAction.embed)

      return effects
    }
  }

  /// Transforms a reducer that works on non-optional state into one that works on optional state by
  /// only running the non-optional reducer when state is non-nil.
  ///
  /// Often used in tandem with ``pullback(state:action:environment:)`` to transform a reducer on a
  /// non-optional child domain into a reducer that can be combined with a reducer on a parent
  /// domain that contains some optional child domain:
  ///
  /// ```swift
  /// // Parent domain that holds an optional child domain:
  /// struct AppState { var modal: ModalState? }
  /// enum AppAction { case modal(ModalAction) }
  /// struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
  ///
  /// // A reducer that works on the non-optional child domain:
  /// let modalReducer = Reducer<ModalState, ModalAction, ModalEnvironment { ... }
  ///
  /// // Pullback the modal reducer so that it works on all of the app domain:
  /// let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  ///   modalReducer.optional().pullback(
  ///     state: \.modal,
  ///     action: /AppAction.modal,
  ///     environment: { ModalEnvironment(mainQueue: $0.mainQueue) }
  ///   ),
  ///   Reducer { state, action, environment in
  ///     ...
  ///   }
  /// )
  /// ```
  ///
  /// Take care when combining optional reducers into parent domains. An optional reducer cannot
  /// process actions in its domain when its state is `nil`. If a child action is sent to an
  /// optional reducer when child state is `nil`, it is generally considered a logic error. There
  /// are a few ways in which these errors can sneak into a code base:
  ///
  ///   * A parent reducer sets child state to `nil` when processing a child action and runs
  ///     _before_ the child reducer:
  ///
  ///     ```swift
  ///     let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  ///       // When combining reducers, the parent reducer runs first
  ///       Reducer { state, action, environment in
  ///         switch action {
  ///         case .child(.didDisappear):
  ///           // And `nil`s out child state when processing a child action
  ///           state.child = nil
  ///           return .none
  ///         ...
  ///         }
  ///       },
  ///       // Before the child reducer runs
  ///       childReducer.optional().pullback(...)
  ///     )
  ///
  ///     let childReducer = Reducer<
  ///       ChildState, ChildAction, ChildEnvironment
  ///     > { state, action environment in
  ///       case .didDisappear:
  ///         // This action is never received here because child state is `nil` in the parent
  ///       ...
  ///     }
  ///     ```
  ///
  ///     To ensure that a child reducer can process any action that a parent may use to `nil` out
  ///     its state, combine it _before_ the parent:
  ///
  ///     ```swift
  ///     let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  ///       // The child runs first
  ///       childReducer.optional().pullback(...),
  ///       // The parent runs after
  ///       Reducer { state, action, environment in
  ///         ...
  ///       }
  ///     )
  ///     ```
  ///
  ///   * A child effect feeds a child action back into the store when child state is `nil`:
  ///
  ///     ```swift
  ///     let childReducer = Reducer<
  ///       ChildState, ChildAction, ChildEnvironment
  ///     > { state, action environment in
  ///       switch action {
  ///       case .onAppear:
  ///         // An effect may want to feed its result back to the child domain in an action
  ///         return environment.apiClient
  ///           .request()
  ///           .map(ChildAction.response)
  ///
  ///       case let .response(response):
  ///         // But the child cannot process this action if its state is `nil` in the parent
  ///       ...
  ///       }
  ///     }
  ///     ```
  ///
  ///     It is perfectly reasonable to ignore the result of an effect when child state is `nil`,
  ///     for example one-off effects that you don't want to cancel. However, many long-living
  ///     effects _should_ be explicitly canceled when tearing down a child domain:
  ///
  ///     ```swift
  ///     let childReducer = Reducer<
  ///       ChildState, ChildAction, ChildEnvironment
  ///     > { state, action environment in
  ///       enum MotionID {}
  ///
  ///       switch action {
  ///       case .onAppear:
  ///         // Mark long-living effects that shouldn't outlive their domain cancellable
  ///         return environment.motionClient
  ///           .start()
  ///           .map(ChildAction.motion)
  ///           .cancellable(id: MotionID.self)
  ///
  ///       case .onDisappear:
  ///         // And explicitly cancel them when the domain is torn down
  ///         return .cancel(id: MotionID.self)
  ///       ...
  ///       }
  ///     }
  ///     ```
  ///
  ///   * A view store sends a child action when child state is `nil`:
  ///
  ///     ```swift
  ///     WithViewStore(self.parentStore) { parentViewStore in
  ///       // If child state is `nil`, it cannot process this action.
  ///       Button("Child Action") { parentViewStore.send(.child(.action)) }
  ///       ...
  ///     }
  ///     ```
  ///
  ///     Use ``Store/scope(state:action:)`` with ``IfLetStore`` or ``Store/ifLet(then:else:)`` to
  ///     ensure that views can only send child actions when the child domain is non-`nil`.
  ///
  ///     ```swift
  ///     IfLetStore(
  ///       self.parentStore.scope(state: { $0.child }, action: { .child($0) }
  ///     ) { childStore in
  ///       // This destination only appears when child state is non-`nil`
  ///       WithViewStore(childStore) { childViewStore in
  ///         // So this action can only be sent when child state is non-`nil`
  ///         Button("Child Action") { childViewStore.send(.action) }
  ///       }
  ///       ...
  ///     }
  ///     ```
  ///
  /// - See also: ``IfLetStore``, a SwiftUI helper for transforming a store on optional state into a
  ///   store on non-optional state.
  /// - See also: ``Store/ifLet(then:else:)``, a UIKit helper for doing imperative work with a store
  ///   on optional state.
  ///
  /// - Returns: A reducer that works on optional state.
  public func optional(
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<
    State?, Action, Environment
  > {
    .init { state, action, environment in
      guard state != nil else {
        runtimeWarning(
          """
          An "optional" reducer at "%@:%d" received an action when state was "nil". …

            Action:
              %@

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • The optional reducer was combined with or run from another reducer that set "%@" to \
          "nil" before the optional reducer ran. Combine or run optional reducers before \
          reducers that can set their state to "nil". This ensures that optional reducers can \
          handle their actions while their state is still non-"nil".

          • An in-flight effect emitted this action while state was "nil". While it may be \
          perfectly reasonable to ignore this action, you may want to cancel the associated \
          effect before state is set to "nil", especially if it is a long-living effect.

          • This action was sent to the store while state was "nil". Make sure that actions for \
          this reducer can only be sent to a view store when state is non-"nil". In SwiftUI \
          applications, use "IfLetStore".
          """,
          [
            "\(fileID)",
            line,
            debugCaseOutput(action),
            "\(State.self)",
          ],
          file: file,
          line: line
        )
        return .none
      }
      return self.reducer(&state!, action, environment)
    }
  }

  /// A version of ``pullback(state:action:environment:)`` that transforms a reducer that works on
  /// an element into one that works on an identified array of elements.
  ///
  /// ```swift
  /// // Parent domain that holds a collection of child domains:
  /// struct AppState { var todos: IdentifiedArrayOf<Todo> }
  /// enum AppAction { case todo(id: Todo.ID, action: TodoAction) }
  /// struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
  ///
  /// // A reducer that works on an element's domain:
  /// let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { ... }
  ///
  /// // Pullback the todo reducer so that it works on all of the app domain:
  /// let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  ///   todoReducer.forEach(
  ///     state: \.todos,
  ///     action: /AppAction.todo(id:action:),
  ///     environment: { _ in TodoEnvironment() }
  ///   ),
  ///   Reducer { state, action, environment in
  ///     ...
  ///   }
  /// )
  /// ```
  ///
  /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
  /// combine `forEach` reducers _before_ parent reducers that can modify the collection.
  ///
  /// - Parameters:
  ///   - toElementsState: A key path that can get/set a collection of `State` elements inside
  ///     `ParentState`.
  ///   - toElementAction: A case path that can extract/embed `(ID, Action)` from `ParentAction`.
  ///   - toElementEnvironment: A function that transforms `ParentEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `ParentState`, `ParentAction`, `ParentEnvironment`.
  public func forEach<ParentState, ParentAction, ParentEnvironment, ID>(
    state toElementsState: WritableKeyPath<ParentState, IdentifiedArray<ID, State>>,
    action toElementAction: CasePath<ParentAction, (ID, Action)>,
    environment toElementEnvironment: @escaping (ParentEnvironment) -> Environment,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<ParentState, ParentAction, ParentEnvironment> {
    .init { parentState, parentAction, parentEnvironment in
      guard let (id, action) = toElementAction.extract(from: parentAction)
      else { return .none }

      if parentState[keyPath: toElementsState][id: id] == nil {
        runtimeWarning(
          """
          A "forEach" reducer at "%@:%d" received an action when state contained no element with \
          that id. …

            Action:
              %@
            ID:
              %@

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • This "forEach" reducer was combined with or run from another reducer that removed \
          the element at this id when it handled this action. To fix this make sure that this \
          "forEach" reducer is run before any other reducers that can move or remove elements \
          from state. This ensures that "forEach" reducers can handle their actions for the \
          element at the intended id.

          • An in-flight effect emitted this action while state contained no element at this id. \
          It may be perfectly reasonable to ignore this action, but you also may want to cancel \
          the effect it originated from when removing an element from the identified array, \
          especially if it is a long-living effect.

          • This action was sent to the store while its state contained no element at this id. \
          To fix this make sure that actions for this reducer can only be sent to a view store \
          when its state contains an element at this id. In SwiftUI applications, use \
          "ForEachStore".
          """,
          [
            "\(fileID)",
            line,
            debugCaseOutput(action),
            "\(id)",
          ],
          file: file,
          line: line
        )
        return .none
      }
      return
        self
        .reducer(
          &parentState[keyPath: toElementsState][id: id]!,
          action,
          toElementEnvironment(parentEnvironment)
        )
        .map { toElementAction.embed((id, $0)) }
    }
  }

  /// A version of ``pullback(state:action:environment:)`` that transforms a reducer that works on
  /// an element into one that works on a dictionary of element values.
  ///
  /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
  /// combine `forEach`` reducers _before_ parent reducers that can modify the dictionary.
  ///
  /// - Parameters:
  ///   - toDictionaryState: A key path that can get/set a dictionary of `State` values inside
  ///     `ParentState`.
  ///   - toKeyedAction: A case path that can extract/embed `(Key, Action)` from `ParentAction`.
  ///   - toValueEnvironment: A function that transforms `ParentEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `ParentState`, `ParentAction`, `ParentEnvironment`.
  public func forEach<ParentState, ParentAction, ParentEnvironment, Key>(
    state toDictionaryState: WritableKeyPath<ParentState, [Key: State]>,
    action toKeyedAction: CasePath<ParentAction, (Key, Action)>,
    environment toValueEnvironment: @escaping (ParentEnvironment) -> Environment,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<ParentState, ParentAction, ParentEnvironment> {
    .init { parentState, parentAction, parentEnvironment in
      guard let (key, action) = toKeyedAction.extract(from: parentAction) else { return .none }

      if parentState[keyPath: toDictionaryState][key] == nil {
        runtimeWarning(
          """
          A "forEach" reducer at "%@:%d" received an action when state contained no value at \
          that key. …

            Action:
              %@
            Key:
              %@

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • This "forEach" reducer was combined with or run from another reducer that removed \
          the element at this key when it handled this action. To fix this make sure that this \
          "forEach" reducer is run before any other reducers that can move or remove elements \
          from state. This ensures that "forEach" reducers can handle their actions for the \
          element at the intended key.

          • An in-flight effect emitted this action while state contained no element at this \
          key. It may be perfectly reasonable to ignore this action, but you also may want to \
          cancel the effect it originated from when removing a value from the dictionary, \
          especially if it is a long-living effect.

          • This action was sent to the store while its state contained no element at this \
          key. To fix this make sure that actions for this reducer can only be sent to a view \
          store when its state contains an element at this key.
          """,
          [
            "\(fileID)",
            line,
            debugCaseOutput(action),
            "\(key)",
          ],
          file: file,
          line: line
        )
        return .none
      }
      return self.reducer(
        &parentState[keyPath: toDictionaryState][key]!,
        action,
        toValueEnvironment(parentEnvironment)
      )
      .map { toKeyedAction.embed((key, $0)) }
    }
  }

  /// Runs the reducer.
  ///
  /// - Parameters:
  ///   - state: Mutable state.
  ///   - action: An action.
  ///   - environment: An environment.
  /// - Returns: An effect that can emit zero or more actions.
  public func run(
    _ state: inout State,
    _ action: Action,
    _ environment: Environment
  ) -> Effect<Action, Never> {
    self.reducer(&state, action, environment)
  }

  public func callAsFunction(
    _ state: inout State,
    _ action: Action,
    _ environment: Environment
  ) -> Effect<Action, Never> {
    self.reducer(&state, action, environment)
  }
}
