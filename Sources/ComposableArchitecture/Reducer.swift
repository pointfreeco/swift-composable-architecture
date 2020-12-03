import CasePaths
import Combine

/// A reducer describes how to evolve the current state of an application to the next state, given
/// an action, and describes what `Effect`s should be executed later by the store, if any.
///
/// Reducers have 3 generics:
///
/// * `State`: A type that holds the current state of the application
/// * `Action`: A type that holds all possible actions that cause the state of the application to
///   change.
/// * `Environment`: A type that holds all dependencies needed in order to produce `Effect`s, such
///   as API clients, analytics clients, random number generators, etc.
///
/// - Note: The thread on which effects output is important. An effect's output is immediately sent
///   back into the store, and `Store` is not thread safe. This means all effects must receive
///   values on the same thread, **and** if the `Store` is being used to drive UI then all output
///   must be on the main thread. You can use the `Publisher` method `receive(on:)` for make the
///   effect output its values on the thread of your choice.
public struct Reducer<State, Action, Environment> {
  private let reducer: (inout State, Action, Environment) -> Effect<Action, Never>

  /// Initializes a reducer from a simple reducer function signature.
  ///
  /// The reducer takes three arguments: state, action and environment. The state is `inout` so that
  /// you can make any changes to it directly inline. The reducer must return an effect, which
  /// typically would be constructed by using the dependencies inside the `environment` value. If
  /// no effect needs to be executed, a `.none` effect can be returned.
  ///
  /// For example:
  ///
  ///     struct MyState { var count = 0, text = "" }
  ///     enum MyAction { case buttonTapped, textChanged(String) }
  ///     struct MyEnvironment { var analyticsClient: AnalyticsClient }
  ///
  ///     let myReducer = Reducer<MyState, MyAction, MyEnvironment> { state, action, environment in
  ///       switch action {
  ///       case .buttonTapped:
  ///         state.count += 1
  ///         return environment.analyticsClient.track("Button Tapped")
  ///
  ///       case .textChanged(let text):
  ///         state.text = text
  ///         return .none
  ///       }
  ///     }
  ///
  /// - Parameter reducer: A function signature that takes state, action and
  ///   environment.
  public init(_ reducer: @escaping (inout State, Action, Environment) -> Effect<Action, Never>) {
    self.reducer = reducer
  }

  /// Initializes a reducer which will only execute the provided handler for a certain action (provided as argument).
  ///
  /// The handler will take three arguments: state, the action's associated value and environment. The state is `inout` so that
  /// you can make any changes to it directly inline. The reducer must return an effect, which
  /// typically would be constructed by using the dependencies inside the `environment` value. If
  /// no effect needs to be executed, a `.none` effect can be returned.
  ///
  /// - Parameters:
  ///   - casePath: The `CasePath` for the action which the Reducer will then call the reducer handler.
  ///   - handler: A function signature that takes state, the action's associated value and environment.
  ///   - state: The current state of the reducer. This is mutable since it is an `inout` variable.
  ///   - actionResult: The associated type of the triggered action.
  ///   - environment: The environment stored in the reducer
  init<ActionResult>(
    forAction casePath: CasePath<Action, ActionResult>,
    handler: @escaping (_ state: inout State, _ actionResult: ActionResult, _ environment: Environment) -> Effect<Action, Never>
  ) {
    self.init { state, action, environment -> Effect<Action, Never> in
      guard let actionResult = casePath.extract(from: action) else { return .none }
      return handler(&state, actionResult, environment)
    }
  }

  /// Initializes a reducer which will only execute the provided handler for a certain action (provided as argument).
  ///
  /// The handler will take two arguments only: state and environment. The action is ignored since it has no associated
  /// type (`Void`). The state is `inout` so that you can make any changes to it directly inline. The reducer must
  /// return an effect, which typically would be constructed by using the dependencies inside the `environment` value.
  /// If no effect needs to be executed, a `.none` effect can be returned.
  ///
  /// - Parameters:
  ///   - casePath: The `CasePath` for the action which the Reducer will then call the reducer handler.
  ///   - handler: A function signature that takes state and environment. Notice that no action is provided
  ///     to the handler since the action has a `Void` associated type.
  ///   - state: The current state of the reducer. This is mutable since it is an `inout` variable.
  ///   - environment: The environment stored in the reducer
  init(
    forAction casePath: CasePath<Action, Void>,
    handler: @escaping (_ state: inout State, _ environment: Environment) -> Effect<Action, Never>
  ) {
    self.init { state, action, environment -> Effect<Action, Never> in
      guard casePath.extract(from: action) != nil else { return .none }
      return handler(&state, environment)
    }
  }

  /// Initializes a reducer which will only execute the provided handler for the provided actions. Notice that all provided actions
  /// must have the same type of associated value.
  ///
  /// The handler will take three arguments: state, the action's associated value and environment. The state is `inout` so that
  /// you can make any changes to it directly inline. The reducer must return an effect, which
  /// typically would be constructed by using the dependencies inside the `environment` value. If
  /// no effect needs to be executed, a `.none` effect can be returned.
  ///
  /// - Parameters:
  ///   - casePaths: All the actions that will be executing the provided handler. All the `CasePath`s must have the same
  ///     resulting type.
  ///   - handler: A function signature that takes state, the action's associated value and environment.
  ///   - state: The current state of the reducer. This is mutable since it is an `inout` variable.
  ///   - actionResult: The associated type of the triggered action.
  ///   - environment: The environment stored in the reducer
  init<ActionResult>(
    forActions casePaths: CasePath<Action, ActionResult>...,
    handler: @escaping (_ state: inout State, _ actionResult: ActionResult, _ environment: Environment) -> Effect<Action, Never>
  ) {
    self.init { state, action, environment -> Effect<Action, Never> in
      for casePath in casePaths {
        guard let actionResult = casePath.extract(from: action) else { continue }
        return handler(&state, actionResult, environment)
      }

      return .none
    }
  }

  /// Initializes a reducer which will only execute the provided handler for the provided actions. Notice that all provided actions
  /// must have no associated value (`Void`).
  ///
  /// The handler will take two arguments only: state and environment. The action is ignored since it has no associated
  /// type (`Void`). The state is `inout` so that you can make any changes to it directly inline. The reducer must
  /// return an effect, which typically would be constructed by using the dependencies inside the `environment` value.
  /// If no effect needs to be executed, a `.none` effect can be returned.
  ///
  /// - Parameters:
  ///   - casePaths: All the actions that will be executing the provided handler. All the `CasePath`s must have no resulting type (`Void`).
  ///   - handler: A function signature that takes state, the action's associated value and environment.
  ///   - state: The current state of the reducer. This is mutable since it is an `inout` variable.
  ///   - environment: The environment stored in the reducer
  init(
    forActions casePaths: CasePath<Action, Void>...,
    handler: @escaping (_ state: inout State, _ environment: Environment) -> Effect<Action, Never>
  ) {
    self.init { state, action, environment -> Effect<Action, Never> in
      for casePath in casePaths {
        guard casePath.extract(from: action) != nil else { continue }
        return handler(&state, environment)
      }

      return .none
    }
  }

  /// Initializes a reducer which will bind a received action associated value to some key path on the reducer's state.
  ///
  /// Optionally you may provide an effect once the assignment is finished.
  ///
  /// - Parameters:
  ///   - casePath: The `CasePath` for the action that we would like to bind to the state. The associated value
  ///     must have the same type as the resulting key path.
  ///   - keyPath: The key path to the property we would like to set in the State. Every new action that this reducer
  ///     receives that matches the provided `casePath` will then store the associated value into the State's key path.
  ///   - handler: A side effect to be produced after the State has been updated with the action's associated value.
  ///     Defaults to not producing any side effects (`.none`).
  ///   - state: The new mutated State, which might even be further mutated if needed.
  ///   - actionResult: The associated value of the triggered action.
  ///   - environment: The environment stored in the reducer.
  init<ActionResult>(
    bindingAction casePath: CasePath<Action, ActionResult>,
    to keyPath: WritableKeyPath<State, ActionResult>,
    handler: @escaping (_ state: inout State, _ actionResult: ActionResult, _ environment: Environment) -> Effect<Action, Never> = { _, _, _ in .none }
  ) {
    self.init(forAction: casePath) { state, actionResult, environment -> Effect<Action, Never> in
      state[keyPath: keyPath] = actionResult
      return handler(&state, actionResult, environment)
    }
  }

  /// Initializes a reducer which will bind received actions associated values to some key path on the reducer's state.
  ///
  /// Optionally you may provide an effect once the assignment is finished.
  ///
  /// - Parameters:
  ///   - casePaths: All the `CasePath`s for the actions that we would like to bind to the state. The associated value
  ///     must have the same type as the resulting key path.
  ///   - keyPath: The key path to the property we would like to set in the State. Every new action that this reducer
  ///     receives that matches the provided `casePaths` will then store the associated value into the State's key path.
  ///   - handler: A side effect to be produced after the State has been updated with the action's associated value.
  ///     Defaults to not producing any side effects (`.none`).
  ///   - state: The new mutated State, which might even be further mutated if needed.
  ///   - actionResult: The associated value of the triggered action.
  ///   - environment: The environment stored in the reducer.
  init<ActionResult>(
    bindingActions casePaths: CasePath<Action, ActionResult>,
    to keyPath: WritableKeyPath<State, ActionResult>,
    handler: @escaping (_ state: inout State, _ actionResult: ActionResult, _ environment: Environment) -> Effect<Action, Never> = { _, _, _ in .none }
  ) {
    self.init(forActions: casePaths) { state, actionResult, environment -> Effect<Action, Never> in
      state[keyPath: keyPath] = actionResult
        return handler(&state, actionResult, environment)
    }
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
  /// This is perhaps most easily seen when working with `optional` reducers, where the parent
  /// domain may listen to the child domain and `nil` out its state. If the parent reducer runs
  /// before the child reducer, then the child reducer will not be able to react to its own action.
  ///
  /// Similar can be said for a `forEach` reducer. If the parent domain modifies the child
  /// collection by moving, removing, or modifying an element before the `forEach` reducer runs, the
  /// `forEach` reducer may perform its action against the wrong element, an element that no longer
  /// exists, or an element in an unexpected state.
  ///
  /// Running a parent reducer before a child reducer can be considered an application logic
  /// error, and can produce assertion failures. So you should almost always combine reducers in
  /// order from child to parent domain.
  ///
  /// Here is an example of how you should combine an `optional` reducer with a parent domain:
  ///
  ///     let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  ///       // Combined before parent so that it can react to `.dismiss` while state is non-`nil`.
  ///       childReducer.optional.pullback(
  ///         state: \.child,
  ///         action: /ParentAction.child,
  ///         environment: { $0.child }
  ///       ),
  ///       // Combined after child so that it can `nil` out child state upon `.child(.dismiss)`.
  ///       Reducer { state, action, environment in
  ///         switch action
  ///         case .child(.dismiss):
  ///           state.child = nil
  ///           return .none
  ///         ...
  ///         }
  ///       },
  ///     )
  ///
  /// - Parameter reducers: A list of reducers.
  /// - Returns: A single reducer.
  public static func combine(_ reducers: Reducer...) -> Reducer {
    .combine(reducers)
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
  /// This is perhaps most easily seen when working with `optional` reducers, where the parent
  /// domain may listen to the child domain and `nil` out its state. If the parent reducer runs
  /// before the child reducer, then the child reducer will not be able to react to its own action.
  ///
  /// Similar can be said for a `forEach` reducer. If the parent domain modifies the child
  /// collection by moving, removing, or modifying an element before the `forEach` reducer runs, the
  /// `forEach` reducer may perform its action against the wrong element, an element that no longer
  /// exists, or an element in an unexpected state.
  ///
  /// Running a parent reducer before a child reducer can be considered an application logic
  /// error, and can produce assertion failures. So you should almost always combine reducers in
  /// order from child to parent domain.
  ///
  /// Here is an example of how you should combine an `optional` reducer with a parent domain:
  ///
  ///     let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  ///       // Combined before parent so that it can react to `.dismiss` while state is non-`nil`.
  ///       childReducer.optional.pullback(
  ///         state: \.child,
  ///         action: /ParentAction.child,
  ///         environment: { $0.child }
  ///       ),
  ///       // Combined after child so that it can `nil` out child state upon `.child(.dismiss)`.
  ///       Reducer { state, action, environment in
  ///         switch action
  ///         case .child(.dismiss):
  ///           state.child = nil
  ///           return .none
  ///         ...
  ///         }
  ///       },
  ///     )
  ///
  /// - Parameter reducers: An array of reducers.
  /// - Returns: A single reducer.
  public static func combine(_ reducers: [Reducer]) -> Reducer {
    Self { value, action, environment in
      .merge(reducers.map { $0.reducer(&value, action, environment) })
    }
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
  /// This is perhaps most easily seen when working with `optional` reducers, where the parent
  /// domain may listen to the child domain and `nil` out its state. If the parent reducer runs
  /// before the child reducer, then the child reducer will not be able to react to its own action.
  ///
  /// Similar can be said for a `forEach` reducer. If the parent domain modifies the child
  /// collection by moving, removing, or modifying an element before the `forEach` reducer runs, the
  /// `forEach` reducer may perform its action against the wrong element, an element that no longer
  /// exists, or an element in an unexpected state.
  ///
  /// Running a parent reducer before a child reducer can be considered an application logic
  /// error, and can produce assertion failures. So you should almost always combine reducers in
  /// order from child to parent domain.
  ///
  /// Here is an example of how you should combine an `optional` reducer with a parent domain:
  ///
  ///     let parentReducer: Reducer<ParentState, ParentAction, ParentEnvironment> =
  ///       // Run before parent so that it can react to `.dismiss` while state is non-`nil`.
  ///       childReducer
  ///         .optional
  ///         .pullback(
  ///           state: \.child,
  ///           action: /ParentAction.child,
  ///           environment: { $0.child }
  ///         )
  ///         // Combined after child so that it can `nil` out child state upon `.child(.dismiss)`.
  ///         .combined(
  ///           with: Reducer { state, action, environment in
  ///             switch action
  ///             case .child(.dismiss):
  ///               state.child = nil
  ///               return .none
  ///             ...
  ///             }
  ///           }
  ///         )
  ///
  /// - Parameter other: Another reducer.
  /// - Returns: A single reducer.
  public func combined(with other: Reducer) -> Reducer {
    .combine(self, other)
  }

  /// Transforms a reducer that works on local state, action and environment into one that works on
  /// global state, action and environment. It accomplishes this by providing 3 transformations to
  /// the method:
  ///
  /// * A writable key path that can get/set a piece of local state from the global state.
  /// * A case path that can extract/embed a local action into a global action.
  /// * A function that can transform the global environment into a local environment.
  ///
  /// This operation is important for breaking down large reducers into small ones. When used with
  /// the `combine` operator you can define many reducers that work on small pieces of domain, and
  /// then _pull them back_ and _combine_ them into one big reducer that works on a large domain.
  ///
  ///     // Global domain that holds a local domain:
  ///     struct AppState { var settings: SettingsState, /* rest of state */ }
  ///     struct AppAction { case settings(SettingsAction), /* other actions */ }
  ///     struct AppEnvironment { var settings: SettingsEnvironment, /* rest of dependencies */ }
  ///
  ///     // A reducer that works on the local domain:
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
  ///
  /// - Parameters:
  ///   - toLocalState: A key path that can get/set `State` inside `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `Action` from `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  public func pullback<GlobalState, GlobalAction, GlobalEnvironment>(
    state toLocalState: WritableKeyPath<GlobalState, State>,
    action toLocalAction: CasePath<GlobalAction, Action>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let localAction = toLocalAction.extract(from: globalAction) else { return .none }
      return self.reducer(
        &globalState[keyPath: toLocalState],
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map(toLocalAction.embed)
    }
  }

  /// Transforms a reducer that works on non-optional state into one that works on optional state by
  /// only running the non-optional reducer when state is non-nil.
  ///
  /// Often used in tandem with `pullback` to transform a reducer on a non-optional local domain
  /// into a reducer that can be combined with a reducer on a global domain that contains some
  /// optional local domain:
  ///
  ///     // Global domain that holds an optional local domain:
  ///     struct AppState { var modal: ModalState? }
  ///     struct AppAction { case modal(ModalAction) }
  ///     struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
  ///
  ///     // A reducer that works on the non-optional local domain:
  ///     let modalReducer = Reducer<ModalState, ModalAction, ModalEnvironment { ... }
  ///
  ///     // Pullback the local modal reducer so that it works on all of the app domain:
  ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  ///       modalReducer.optional().pullback(
  ///         state: \.modal,
  ///         action: /AppAction.modal,
  ///         environment: { ModalEnvironment(mainQueue: $0.mainQueue) }
  ///       ),
  ///       Reducer { state, action, environment in
  ///         ...
  ///       }
  ///     )
  ///
  /// Take care when combining optional reducers into parent domains, as order matters. Always
  /// combine optional reducers _before_ parent reducers that can `nil` out the associated optional
  /// state.
  ///
  /// - See also: `IfLetStore`, a SwiftUI helper for transforming a store on optional state into a
  ///   store on non-optional state.
  /// - See also: `Store.ifLet`, a UIKit helper for doing imperative work with a store on optional
  ///   state.
  public func optional(_ file: StaticString = #file, _ line: UInt = #line) -> Reducer<
    State?, Action, Environment
  > {
    .init { state, action, environment in
      guard state != nil else {
        assertionFailure(
          """
          "\(debugCaseOutput(action))" was received by an optional reducer when its state was \
          "nil". This can happen for a few reasons:

          * The optional reducer was combined with or run from another reducer that set \
          "\(State.self)" to "nil" before the optional reducer ran. Combine or run optional \
          reducers before reducers that can set their state to "nil". This ensures that optional \
          reducers can handle their actions while their state is still non-"nil".

          * An active effect emitted this action while state was "nil". Make sure that effects for \
          this optional reducer are canceled when optional state is set to "nil".

          * This action was sent to the store while state was "nil". Make sure that actions for \
          this reducer can only be sent to a view store when state is non-"nil". In SwiftUI \
          applications, use "IfLetStore".
          """,
          file: file,
          line: line
        )
        return .none
      }
      return self.reducer(&state!, action, environment)
    }
  }

  /// A version of `pullback` that transforms a reducer that works on an element into one that works
  /// on a collection of elements.
  ///
  ///     // Global domain that holds a collection of local domains:
  ///     struct AppState { var todos: [Todo] }
  ///     struct AppAction { case todo(index: Int, action: TodoAction) }
  ///     struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
  ///
  ///     // A reducer that works on a local domain:
  ///     let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { ... }
  ///
  ///     // Pullback the local todo reducer so that it works on all of the app domain:
  ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  ///       todoReducer.forEach(
  ///         state: \.todos,
  ///         action: /AppAction.todo(index:action:),
  ///         environment: { _ in TodoEnvironment() }
  ///       ),
  ///       Reducer { state, action, environment in
  ///         ...
  ///       }
  ///     )
  ///
  /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
  /// combine `forEach` reducers _before_ parent reducers that can modify the collection.
  ///
  /// - Parameters:
  ///   - toLocalState: A key path that can get/set an array of `State` elements inside.
  ///     `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `(Int, Action)` from `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  public func forEach<GlobalState, GlobalAction, GlobalEnvironment>(
    state toLocalState: WritableKeyPath<GlobalState, [State]>,
    action toLocalAction: CasePath<GlobalAction, (Int, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    _ file: StaticString = #file,
    _ line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (index, localAction) = toLocalAction.extract(from: globalAction) else {
        return .none
      }
      // NB: This does not need to be a fatal error because of the index subscript that follows it.
      assert(
        index < globalState[keyPath: toLocalState].endIndex,
        """
        "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at index \(index) \
        when its state contained no element at this index. This is considered an application logic \
        error, and can happen for a few reasons:

        * This "forEach" reducer was combined with or run from another reducer that removed the \
        element at this index when it handled this action. To fix this make sure that this \
        "forEach" reducer is run before any other reducers that can move or remove elements from \
        state. This ensures that "forEach" reducers can handle their actions for the element at \
        the intended index.

        * An in-flight effect emitted this action while state contained no element at this index. \
        To fix this make sure that effects for this "forEach" reducer are canceled whenever \
        elements are moved or removed from its state. If your "forEach" reducer returns any \
        long-living effects, you should use the identifier-based "forEach", instead.

        * This action was sent to the store while its state contained no element at this index. \
        To fix this make sure that actions for this reducer can only be sent to a view store when \
        its state contains an element at this index. In SwiftUI applications, use `ForEachStore`.
        """,
        file: file,
        line: line
      )
      return self.reducer(
        &globalState[keyPath: toLocalState][index],
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map { toLocalAction.embed((index, $0)) }
    }
  }

  /// A version of `pullback` that transforms a reducer that works on an element into one that works
  /// on an identified array of elements.
  ///
  ///     // Global domain that holds a collection of local domains:
  ///     struct AppState { var todos: IdentifiedArrayOf<Todo> }
  ///     struct AppAction { case todo(id: Todo.ID, action: TodoAction) }
  ///     struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
  ///
  ///     // A reducer that works on a local domain:
  ///     let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { ... }
  ///
  ///     // Pullback the local todo reducer so that it works on all of the app domain:
  ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  ///       todoReducer.forEach(
  ///         state: \.todos,
  ///         action: /AppAction.todo(id:action:),
  ///         environment: { _ in TodoEnvironment() }
  ///       ),
  ///       Reducer { state, action, environment in
  ///         ...
  ///       }
  ///     )
  ///
  /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
  /// combine `forEach` reducers _before_ parent reducers that can modify the collection.
  ///
  /// - Parameters:
  ///   - toLocalState: A key path that can get/set a collection of `State` elements inside
  ///     `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `(Collection.Index, Action)` from
  ///     `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  public func forEach<GlobalState, GlobalAction, GlobalEnvironment, ID>(
    state toLocalState: WritableKeyPath<GlobalState, IdentifiedArray<ID, State>>,
    action toLocalAction: CasePath<GlobalAction, (ID, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    _ file: StaticString = #file,
    _ line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (id, localAction) = toLocalAction.extract(from: globalAction) else { return .none }

      // This does not need to be a fatal error because of the unwrap that follows it.
      assert(
        globalState[keyPath: toLocalState][id: id] != nil,
        """
        "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at id \(id) \
        when its state contained no element at this id. This is considered an application logic \
        error, and can happen for a few reasons:

        * This "forEach" reducer was combined with or run from another reducer that removed the \
        element at this id when it handled this action. To fix this make sure that this \
        "forEach" reducer is run before any other reducers that can move or remove elements from \
        state. This ensures that "forEach" reducers can handle their actions for the element at \
        the intended id.

        * An in-flight effect emitted this action while state contained no element at this id. \
        To fix this make sure that effects for this "forEach" reducer are canceled whenever \
        elements are moved or removed from its state. If your "forEach" reducer returns any \
        long-living effects, you should use the identifier-based "forEach", instead.

        * This action was sent to the store while its state contained no element at this id. \
        To fix this make sure that actions for this reducer can only be sent to a view store when \
        its state contains an element at this id. In SwiftUI applications, use `ForEachStore`.
        """,
        file: file,
        line: line
      )

      return
        self
        .reducer(
          &globalState[keyPath: toLocalState][id: id]!,
          localAction,
          toLocalEnvironment(globalEnvironment)
        )
        .map { toLocalAction.embed((id, $0)) }
    }
  }

  /// A version of `pullback` that transforms a reducer that works on an element into one that works
  /// on a dictionary of element values.
  ///
  /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
  /// combine `forEach` reducers _before_ parent reducers that can modify the dictionary.
  ///
  /// - Parameters:
  ///   - toLocalState: A key path that can get/set a dictionary of `State` values inside
  ///     `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `(Key, Action)` from `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  public func forEach<GlobalState, GlobalAction, GlobalEnvironment, Key>(
    state toLocalState: WritableKeyPath<GlobalState, [Key: State]>,
    action toLocalAction: CasePath<GlobalAction, (Key, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    _ file: StaticString = #file,
    _ line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (key, localAction) = toLocalAction.extract(from: globalAction) else { return .none }

      assert(
        globalState[keyPath: toLocalState][key] != nil,
        """
        "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at key \(key) \
        when its state contained no element at this key. This is considered an application logic \
        error, and can happen for a few reasons:

        * This "forEach" reducer was combined with or run from another reducer that removed the \
        element at this key when it handled this action. To fix this make sure that this \
        "forEach" reducer is run before any other reducers that can move or remove elements from \
        state. This ensures that "forEach" reducers can handle their actions for the element at \
        the intended key.

        * An in-flight effect emitted this action while state contained no element at this key. \
        To fix this make sure that effects for this "forEach" reducer are canceled whenever \
        elements are moved or removed from its state.

        * This action was sent to the store while its state contained no element at this key. \
        To fix this make sure that actions for this reducer can only be sent to a view store
        when its state contains an element at this key.
        """,
        file: file,
        line: line
      )
      return self.reducer(
        &globalState[keyPath: toLocalState][key]!,
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map { toLocalAction.embed((key, $0)) }
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
