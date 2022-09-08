import Combine
import Foundation

/// A store represents the runtime that powers the application. It is the object that you will pass
/// around to views that need to interact with the application.
///
/// You will typically construct a single one of these at the root of your application, and then use
/// the ``scope(state:action:)`` method to derive more focused stores that can be passed to
/// subviews:
///
/// ```swift
/// @main
/// struct MyApp: App {
///   var body: some Scene {
///     WindowGroup {
///       RootView(
///         store: Store(
///           initialState: AppState(),
///           reducer: appReducer,
///           environment: AppEnvironment(
///             ...
///           )
///         )
///       )
///     }
///   }
/// }
/// ```
///
/// ### Scoping
///
/// The most important operation defined on ``Store`` is the ``scope(state:action:)`` method, which
/// allows you to transform a store into one that deals with child state and actions. This is
/// necessary for passing stores to subviews that only care about a small portion of the entire
/// application's domain.
///
/// For example, if an application has a tab view at its root with tabs for activity, search, and
/// profile, then we can model the domain like this:
///
/// ```swift
/// struct AppState {
///   var activity: ActivityState
///   var profile: ProfileState
///   var search: SearchState
/// }
///
/// enum AppAction {
///   case activity(ActivityAction)
///   case profile(ProfileAction)
///   case search(SearchAction)
/// }
/// ```
///
/// We can construct a view for each of these domains by applying ``scope(state:action:)`` to a
/// store that holds onto the full app domain in order to transform it into a store for each
/// sub-domain:
///
/// ```swift
/// struct AppView: View {
///   let store: Store<AppState, AppAction>
///
///   var body: some View {
///     TabView {
///       ActivityView(store: self.store.scope(state: \.activity, action: AppAction.activity))
///         .tabItem { Text("Activity") }
///
///       SearchView(store: self.store.scope(state: \.search, action: AppAction.search))
///         .tabItem { Text("Search") }
///
///       ProfileView(store: self.store.scope(state: \.profile, action: AppAction.profile))
///         .tabItem { Text("Profile") }
///     }
///   }
/// }
/// ```
///
/// ### Thread safety
///
/// The `Store` class is not thread-safe, and so all interactions with an instance of ``Store``
/// (including all of its scopes and derived ``ViewStore``s) must be done on the same thread the
/// store was created on. Further, if the store is powering a SwiftUI or UIKit view, as is
/// customary, then all interactions must be done on the _main_ thread.
///
/// The reason stores are not thread-safe is due to the fact that when an action is sent to a store,
/// a reducer is run on the current state, and this process cannot be done from multiple threads.
/// It is possible to make this process thread-safe by introducing locks or queues, but this
/// introduces new complications:
///
///   * If done simply with `DispatchQueue.main.async` you will incur a thread hop even when you are
///     already on the main thread. This can lead to unexpected behavior in UIKit and SwiftUI, where
///     sometimes you are required to do work synchronously, such as in animation blocks.
///
///   * It is possible to create a scheduler that performs its work immediately when on the main
///     thread and otherwise uses `DispatchQueue.main.async` (_e.g._, see Combine Schedulers'
///     [UIScheduler][uischeduler]).
///
/// This introduces a lot more complexity, and should probably not be adopted without having a very
/// good reason.
///
/// This is why we require all actions be sent from the same thread. This requirement is in the same
/// spirit of how `URLSession` and other Apple APIs are designed. Those APIs tend to deliver their
/// outputs on whatever thread is most convenient for them, and then it is your responsibility to
/// dispatch back to the main queue if that's what you need. The Composable Architecture makes you
/// responsible for making sure to send actions on the main thread. If you are using an effect that
/// may deliver its output on a non-main thread, you must explicitly perform `.receive(on:)` in
/// order to force it back on the main thread.
///
/// This approach makes the fewest number of assumptions about how effects are created and
/// transformed, and prevents unnecessary thread hops and re-dispatching. It also provides some
/// testing benefits. If your effects are not responsible for their own scheduling, then in tests
/// all of the effects would run synchronously and immediately. You would not be able to test how
/// multiple in-flight effects interleave with each other and affect the state of your application.
/// However, by leaving scheduling out of the ``Store`` we get to test these aspects of our effects
/// if we so desire, or we can ignore if we prefer. We have that flexibility.
///
/// [uischeduler]: https://github.com/pointfreeco/combine-schedulers/blob/main/Sources/CombineSchedulers/UIScheduler.swift
///
/// #### Thread safety checks
///
/// The store performs some basic thread safety checks in order to help catch mistakes. Stores
/// constructed via the initializer ``init(initialState:reducer:environment:)`` are assumed to run
/// only on the main thread, and so a check is executed immediately to make sure that is the case.
/// Further, all actions sent to the store and all scopes (see ``scope(state:action:)``) of the
/// store are also checked to make sure that work is performed on the main thread.
public final class Store<State, Action> {
  private var bufferedActions: [Action] = []
  var effectCancellables: [UUID: AnyCancellable] = [:]
  private var isSending = false
  var parentCancellable: AnyCancellable?
  private let reducer: (inout State, Action) -> Effect<Action, Never>
  fileprivate var scope: AnyScope?
  var state: CurrentValueSubject<State, Never>
  #if DEBUG
    private let mainThreadChecksEnabled: Bool
  #endif

  /// Initializes a store from an initial state, a reducer, and an environment.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the application in.
  ///   - reducer: The reducer that powers the business logic of the application.
  ///   - environment: The environment of dependencies for the application.
  public convenience init<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) {
    self.init(
      initialState: initialState,
      reducer: reducer,
      environment: environment,
      mainThreadChecksEnabled: true
    )
    self.threadCheck(status: .`init`)
  }

  /// Scopes the store to one that exposes child state and actions.
  ///
  /// This can be useful for deriving new stores to hand to child views in an application. For
  /// example:
  ///
  /// ```swift
  /// // Application state made from child states.
  /// struct AppState { var login: LoginState, ... }
  /// enum AppAction { case login(LoginAction), ... }
  ///
  /// // A store that runs the entire application.
  /// let store = Store(
  ///   initialState: AppState(),
  ///   reducer: appReducer,
  ///   environment: AppEnvironment()
  /// )
  ///
  /// // Construct a login view by scoping the store to one that works with only login domain.
  /// LoginView(
  ///   store: store.scope(
  ///     state: \.login,
  ///     action: AppAction.login
  ///   )
  /// )
  /// ```
  ///
  /// Scoping in this fashion allows you to better modularize your application. In this case,
  /// `LoginView` could be extracted to a module that has no access to `AppState` or `AppAction`.
  ///
  /// Scoping also gives a view the opportunity to focus on just the state and actions it cares
  /// about, even if its feature domain is larger.
  ///
  /// For example, the above login domain could model a two screen login flow: a login form followed
  /// by a two-factor authentication screen. The second screen's domain might be nested in the
  /// first:
  ///
  /// ```swift
  /// struct LoginState: Equatable {
  ///   var email = ""
  ///   var password = ""
  ///   var twoFactorAuth: TwoFactorAuthState?
  /// }
  ///
  /// enum LoginAction: Equatable {
  ///   case emailChanged(String)
  ///   case loginButtonTapped
  ///   case loginResponse(Result<TwoFactorAuthState, LoginError>)
  ///   case passwordChanged(String)
  ///   case twoFactorAuth(TwoFactorAuthAction)
  /// }
  /// ```
  ///
  /// The login view holds onto a store of this domain:
  ///
  /// ```swift
  /// struct LoginView: View {
  ///   let store: Store<LoginState, LoginAction>
  ///
  ///   var body: some View { ... }
  /// }
  /// ```
  ///
  /// If its body were to use a view store of the same domain, this would introduce a number of
  /// problems:
  ///
  /// * The login view would be able to read from `twoFactorAuth` state. This state is only intended
  ///   to be read from the two-factor auth screen.
  ///
  /// * Even worse, changes to `twoFactorAuth` state would now cause SwiftUI to recompute
  ///   `LoginView`'s body unnecessarily.
  ///
  /// * The login view would be able to send `twoFactorAuth` actions. These actions are only
  ///   intended to be sent from the two-factor auth screen (and reducer).
  ///
  /// * The login view would be able to send non user-facing login actions, like `loginResponse`.
  ///   These actions are only intended to be used in the login reducer to feed the results of
  ///   effects back into the store.
  ///
  /// To avoid these issues, one can introduce a view-specific domain that slices off the subset of
  /// state and actions that a view cares about:
  ///
  /// ```swift
  /// extension LoginView {
  ///   struct State: Equatable {
  ///     var email: String
  ///     var password: String
  ///   }
  ///
  ///   enum Action: Equatable {
  ///     case emailChanged(String)
  ///     case loginButtonTapped
  ///     case passwordChanged(String)
  ///   }
  /// }
  /// ```
  ///
  /// One can also introduce a couple helpers that transform feature state into view state and
  /// transform view actions into feature actions.
  ///
  /// ```swift
  /// extension LoginState {
  ///   var view: LoginView.State {
  ///     .init(email: self.email, password: self.password)
  ///   }
  /// }
  ///
  /// extension LoginView.Action {
  ///   var feature: LoginAction {
  ///     switch self {
  ///     case let .emailChanged(email)
  ///       return .emailChanged(email)
  ///     case .loginButtonTapped:
  ///       return .loginButtonTapped
  ///     case let .passwordChanged(password)
  ///       return .passwordChanged(password)
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// With these helpers defined, `LoginView` can now scope its store's feature domain into its view
  /// domain:
  ///
  /// ```swift
  ///  var body: some View {
  ///    WithViewStore(
  ///      self.store, observe: \.view, send: \.feature
  ///    ) { viewStore in
  ///      ...
  ///    }
  ///  }
  /// ```
  ///
  /// This view store is now incapable of reading any state but view state (and will not recompute
  /// when non-view state changes), and is incapable of sending any actions but view actions.
  ///
  /// - Parameters:
  ///   - toChildState: A function that transforms `State` into `ChildState`.
  ///   - fromChildAction: A function that transforms `ChildAction` into `Action`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (State) -> ChildState,
    action fromChildAction: @escaping (ChildAction) -> Action
  ) -> Store<ChildState, ChildAction> {
    self.threadCheck(status: .scope)

    return (self.scope ?? Scope(root: self))
      .rescope(self, state: toChildState, action: fromChildAction)
  }

  /// Scopes the store to one that exposes child state.
  ///
  /// A version of ``scope(state:action:)`` that leaves the action type unchanged.
  ///
  /// - Parameter toChildState: A function that transforms `State` into `ChildState`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<ChildState>(
    state toChildState: @escaping (State) -> ChildState
  ) -> Store<ChildState, Action> {
    self.scope(state: toChildState, action: { $0 })
  }

  func send(
    _ action: Action,
    originatingFrom originatingAction: Action? = nil
  ) -> Task<Void, Never>? {
    self.threadCheck(status: .send(action, originatingAction: originatingAction))

    self.bufferedActions.append(action)
    guard !self.isSending else { return nil }

    self.isSending = true
    var currentState = self.state.value
    let tasks = Box<[Task<Void, Never>]>(wrappedValue: [])
    defer {
      withExtendedLifetime(self.bufferedActions) {
        self.bufferedActions.removeAll()
      }
      self.isSending = false
      self.state.value = currentState
      // NB: Handle any re-entrant actions
      if !self.bufferedActions.isEmpty {
        if let task = self.send(
          self.bufferedActions.removeLast(), originatingFrom: originatingAction
        ) {
          tasks.wrappedValue.append(task)
        }
      }
    }

    var index = self.bufferedActions.startIndex
    while index < self.bufferedActions.endIndex {
      defer { index += 1 }
      let action = self.bufferedActions[index]
      let effect = self.reducer(&currentState, action)

      switch effect.operation {
      case .none:
        break
      case let .publisher(publisher):
        var didComplete = false
        let boxedTask = Box<Task<Void, Never>?>(wrappedValue: nil)
        let uuid = UUID()
        let effectCancellable =
          publisher
          .handleEvents(
            receiveCancel: { [weak self] in
              self?.threadCheck(status: .effectCompletion(action))
              self?.effectCancellables[uuid] = nil
            }
          )
          .sink(
            receiveCompletion: { [weak self] _ in
              self?.threadCheck(status: .effectCompletion(action))
              boxedTask.wrappedValue?.cancel()
              didComplete = true
              self?.effectCancellables[uuid] = nil
            },
            receiveValue: { [weak self] effectAction in
              guard let self = self else { return }
              if let task = self.send(effectAction, originatingFrom: action) {
                tasks.wrappedValue.append(task)
              }
            }
          )

        if !didComplete {
          let task = Task<Void, Never> { @MainActor in
            for await _ in AsyncStream<Void>.never {}
            effectCancellable.cancel()
          }
          boxedTask.wrappedValue = task
          tasks.wrappedValue.append(task)
          self.effectCancellables[uuid] = effectCancellable
        }
      case let .run(priority, operation):
        tasks.wrappedValue.append(
          Task(priority: priority) {
            await operation(
              Send {
                if let task = self.send($0, originatingFrom: action) {
                  tasks.wrappedValue.append(task)
                }
              }
            )
          }
        )
      }
    }

    guard !tasks.wrappedValue.isEmpty else { return nil }
    return Task {
      await withTaskCancellationHandler {
        var index = tasks.wrappedValue.startIndex
        while index < tasks.wrappedValue.endIndex {
          defer { index += 1 }
          tasks.wrappedValue[index].cancel()
        }
      } operation: {
        var index = tasks.wrappedValue.startIndex
        while index < tasks.wrappedValue.endIndex {
          defer { index += 1 }
          await tasks.wrappedValue[index].value
        }
      }
    }
  }

  /// Returns a "stateless" store by erasing state to `Void`.
  public var stateless: Store<Void, Action> {
    self.scope(state: { _ in () })
  }

  /// Returns an "actionless" store by erasing action to `Never`.
  public var actionless: Store<State, Never> {
    func absurd<A>(_ never: Never) -> A {}
    return self.scope(state: { $0 }, action: absurd)
  }

  private enum ThreadCheckStatus {
    case effectCompletion(Action)
    case `init`
    case scope
    case send(Action, originatingAction: Action?)
  }

  @inline(__always)
  private func threadCheck(status: ThreadCheckStatus) {
    #if DEBUG
      guard self.mainThreadChecksEnabled && !Thread.isMainThread
      else { return }

      switch status {
      case let .effectCompletion(action):
        runtimeWarning(
          """
          An effect completed on a non-main thread. …

            Effect returned from:
              %@

          Make sure to use ".receive(on:)" on any effects that execute on background threads to \
          receive their output on the main thread.

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """,
          [debugCaseOutput(action)]
        )

      case .`init`:
        runtimeWarning(
          """
          A store initialized on a non-main thread. …

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """
        )

      case .scope:
        runtimeWarning(
          """
          "Store.scope" was called on a non-main thread. …

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """
        )

      case let .send(action, originatingAction: nil):
        runtimeWarning(
          """
          "ViewStore.send" was called on a non-main thread with: %@ …

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """,
          [debugCaseOutput(action)]
        )

      case let .send(action, originatingAction: .some(originatingAction)):
        runtimeWarning(
          """
          An effect published an action on a non-main thread. …

            Effect published:
              %@

            Effect returned from:
              %@

          Make sure to use ".receive(on:)" on any effects that execute on background threads to \
          receive their output on the main thread.

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """,
          [
            debugCaseOutput(action),
            debugCaseOutput(originatingAction),
          ]
        )
      }
    #endif
  }

  init<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment,
    mainThreadChecksEnabled: Bool
  ) {
    self.state = CurrentValueSubject(initialState)
    self.reducer = { state, action in reducer.run(&state, action, environment) }

    #if DEBUG
      self.mainThreadChecksEnabled = mainThreadChecksEnabled
    #endif
  }
}

private protocol AnyScope {
  func rescope<ScopedState, ScopedAction, RescopedState, RescopedAction>(
    _ store: Store<ScopedState, ScopedAction>,
    state toRescopedState: @escaping (ScopedState) -> RescopedState,
    action fromRescopedAction: @escaping (RescopedAction) -> ScopedAction
  ) -> Store<RescopedState, RescopedAction>
}

private struct Scope<RootState, RootAction>: AnyScope {
  let root: Store<RootState, RootAction>
  let fromScopedAction: Any

  init(root: Store<RootState, RootAction>) {
    self.init(root: root, fromScopedAction: { $0 })
  }

  private init<ScopedAction>(
    root: Store<RootState, RootAction>,
    fromScopedAction: @escaping (ScopedAction) -> RootAction
  ) {
    self.root = root
    self.fromScopedAction = fromScopedAction
  }

  func rescope<ScopedState, ScopedAction, RescopedState, RescopedAction>(
    _ scopedStore: Store<ScopedState, ScopedAction>,
    state toRescopedState: @escaping (ScopedState) -> RescopedState,
    action fromRescopedAction: @escaping (RescopedAction) -> ScopedAction
  ) -> Store<RescopedState, RescopedAction> {
    let fromScopedAction = self.fromScopedAction as! (ScopedAction) -> RootAction

    var isSending = false
    let rescopedStore = Store<RescopedState, RescopedAction>(
      initialState: toRescopedState(scopedStore.state.value),
      reducer: .init { rescopedState, rescopedAction, _ in
        isSending = true
        defer { isSending = false }
        let task = self.root.send(fromScopedAction(fromRescopedAction(rescopedAction)))
        rescopedState = toRescopedState(scopedStore.state.value)
        if let task = task {
          return .fireAndForget { await task.cancellableValue }
        } else {
          return .none
        }
      },
      environment: ()
    )
    rescopedStore.parentCancellable = scopedStore.state
      .dropFirst()
      .sink { [weak rescopedStore] newValue in
        guard !isSending else { return }
        rescopedStore?.state.value = toRescopedState(newValue)
      }
    rescopedStore.scope = Scope<RootState, RootAction>(
      root: self.root,
      fromScopedAction: { fromScopedAction(fromRescopedAction($0)) }
    )
    return rescopedStore
  }
}
