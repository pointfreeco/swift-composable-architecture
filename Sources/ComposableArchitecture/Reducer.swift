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

  /// Creates a reducer from a reducer function signature that does not take the environment as
  /// input, but instead returns a function that gets access to the environment. This makes it
  /// *impossible* to access the environment and invoke any effects directly in the reducer, which
  /// should never be done.
  ///
  /// For example:
  ///
  ///     struct MyState { var count = 0, text = "" }
  ///     enum MyAction { case buttonTapped, textChanged(String) }
  ///     struct MyEnvironment { var analyticsClient: AnalyticsClient }
  ///
  ///     let myReducer = Reducer<MyState, MyAction, MyEnvironment>.strict { state, action in
  ///       switch action {
  ///       case .buttonTapped:
  ///         state.count += 1
  ///         return { environment in
  ///           environment.analyticsClient.track("Button Tapped")
  ///         }
  ///
  ///       case .textChanged(let text):
  ///         state.text = text
  ///         return .none
  ///       }
  ///     }
  ///
  /// - Parameter reducer: A function signature that takes state and action, and returns a
  ///   function that takes an environment and returns an effect.
  /// - Returns: A reducer.
  public static func strict(
    _ reducer: @escaping (inout State, Action) -> (Environment) -> Effect<Action, Never>
  ) -> Reducer {
    .init { state, action, environment in
      reducer(&state, action)(environment)
    }
  }

  /// A reducer that performs no state mutations and returns no effects.
  public static var empty: Reducer {
    Self { _, _, _ in .none }
  }

  /// Combines many reducers into a single one by running each one on the state, and merging all of
  /// the effects together.
  ///
  /// - Parameter reducers: A list of reducers.
  /// - Returns: A single reducer.
  public static func combine(_ reducers: Reducer...) -> Reducer {
    .combine(reducers)
  }

  /// Combines an array of reducers into a single one by running each one on the state, and
  /// concatenating all of the arrays of effects.
  ///
  /// - Parameter reducers: An array of reducers.
  /// - Returns: A single reducer.
  public static func combine(_ reducers: [Reducer]) -> Reducer {
    Self { value, action, environment in
      .merge(reducers.map { $0.reducer(&value, action, environment) })
    }
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
  /// into a reducer on a global domain that contains an optional local domain:
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
  ///     let appReducer: Reducer<AppState, AppAction, AppEnvironment> =
  ///       modalReducer.optional.pullback(
  ///         state: \.modal,
  ///         action: /AppAction.modal,
  ///         environment: { ModalEnvironment(mainQueue: $0.mainQueue) }
  ///       )
  ///
  /// - See also: `IfLetStore`, a SwiftUI helper for transforming a store on optional state into a
  ///   store on non-optional state.
  /// - See also: `Store.ifLet`, a UIKit helper for doing imperative work with a store on optional
  ///   state.
  public var optional: Reducer<State?, Action, Environment> {
    .init { state, action, environment in
      guard state != nil else { return .none }
      return self.callAsFunction(&state!, action, environment)
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
  ///     let appReducer: Reducer<AppState, AppAction, AppEnvironment> =
  ///       todoReducer.forEach(
  ///         state: \.todos,
  ///         action: /AppAction.todo(index:action:),
  ///         environment: { _ in TodoEnvironment() }
  ///       )
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
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (index, localAction) = toLocalAction.extract(from: globalAction) else {
        return .none
      }
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
  ///     let appReducer: Reducer<AppState, AppAction, AppEnvironment> =
  ///       todoReducer.forEach(
  ///         state: \.todos,
  ///         action: /AppAction.todo(id:action:),
  ///         environment: { _ in TodoEnvironment() }
  ///       )
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
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (id, localAction) = toLocalAction.extract(from: globalAction) else { return .none }
      return self.optional
        .reducer(
          &globalState[keyPath: toLocalState][id],
          localAction,
          toLocalEnvironment(globalEnvironment)
        )
        .map { toLocalAction.embed((id, $0)) }
    }
  }

  /// A version of `pullback` that transforms a reducer that works on an element into one that works
  /// on a dictionary of element values.
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
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (key, localAction) = toLocalAction.extract(from: globalAction) else { return .none }
      return self.optional
        .reducer(
          &globalState[keyPath: toLocalState][key],
          localAction,
          toLocalEnvironment(globalEnvironment)
        )
        .map { toLocalAction.embed((key, $0)) }
    }
  }

  public func callAsFunction(
    _ state: inout State,
    _ action: Action,
    _ environment: Environment
  ) -> Effect<Action, Never> {
    self.reducer(&state, action, environment)
  }
}

extension Reducer where Environment == Void {
  public func callAsFunction(
    _ state: inout State,
    _ action: Action
  ) -> Effect<Action, Never> {
    self.callAsFunction(&state, action, ())
  }
}
