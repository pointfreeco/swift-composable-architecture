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
/// allows you to transform a store into one that deals with local state and actions. This is
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
/// ```
///
/// ### Thread safety
///
/// The `Store` class is not thread-safe, and so all interactions with an instance of ``Store``
/// (including all of its scopes and derived ``ViewStore``s) must be done on the same thread.
/// Further, if the store is powering a SwiftUI or UIKit view, as is customary, then all
/// interactions must be done on the _main_ thread.
///
/// The reason stores are not thread-safe is due to the fact that when an action is sent to a store,
/// a reducer is run on the current state, and this process cannot be done from multiple threads.
/// It is possible to make this process thread-safe by introducing locks or queues, but this
/// introduces new complications:
///
/// * If done simply with `DispatchQueue.main.async` you will incur a thread hop even when you are
/// already on the main thread. This can lead to unexpected behavior in UIKit and SwiftUI, where
/// sometimes you are required to do work synchronously, such as in animation blocks.
///
/// * It is possible to create a scheduler that performs its work immediately when on the main
/// thread and otherwise uses `DispatchQueue.main.async` (e.g. see CombineScheduler's
/// [UIScheduler](https://github.com/pointfreeco/combine-schedulers/blob/main/Sources/CombineSchedulers/UIScheduler.swift)).
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
/// See also: ``ViewStore`` to understand how one observes changes to the state in a ``Store`` and
/// sends user actions.
public final class Store<State, Action> {
  var state: CurrentValueSubject<State, Never>
  var effectCancellables: [UUID: AnyCancellable] = [:]
  private var isSending = false
  private var parentCancellable: AnyCancellable?
  private let reducer: (inout State, Action) -> Effect<Action, Never>
  private var bufferedActions: [Action] = []
  #if DEBUG
  private let dispatchToken: UUID?
  #endif

  /// Initializes a store from an initial state, a reducer, an environment, and a dispatch queue.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the application in.
  ///   - reducer: The reducer that powers the business logic of the application.
  ///   - environment: The environment of dependencies for the application.
  ///   - dispatchQueue: Some dispatch queue onto which the store is assumed to process
  ///   operations. If no queue is specified, the store should run on the main queue.
  ///
  /// - Note: You are responsible for dispatching store's operations on the correct queue.
  public convenience init<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment,
    dispatchQueue: DispatchQueue = .main
  ) {
    
    let token: UUID?
    if dispatchQueue != DispatchQueue.main {
      token = UUID()
      var tokens = dispatchQueue.getSpecific(key: storeDispatchSpecificKey) ?? []
      tokens.insert(token!)
      dispatchQueue.setSpecific(key: storeDispatchSpecificKey, value: tokens)
    } else {
      token = nil
    }
    
    self.init(
      initialState: initialState,
      reducer: reducer,
      environment: environment,
      dispatchToken: token
    )
  }

  private init<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment,
    dispatchToken: UUID?
  ) {
    #if DEBUG
    self.dispatchToken = dispatchToken
    #endif
    self.state = CurrentValueSubject(initialState)
    self.reducer = { state, action in reducer.run(&state, action, environment) }
  }

  /// Scopes the store to one that exposes local state and actions.
  ///
  /// This can be useful for deriving new stores to hand to child views in an application. For
  /// example:
  ///
  /// ```swift
  /// // Application state made from local states.
  /// struct AppState { var login: LoginState, ... }
  /// struct AppAction { case login(LoginAction), ... }
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
  ///      self.store.scope(state: \.view, action: \.feature)
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
  ///   - toLocalState: A function that transforms `State` into `LocalState`.
  ///   - fromLocalAction: A function that transforms `LocalAction` into `Action`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<LocalState, LocalAction>(
    state toLocalState: @escaping (State) -> LocalState,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> Store<LocalState, LocalAction> {
    self.threadCheck(status: .scope)
    var isSending = false
    let localStore = Store<LocalState, LocalAction>(
      initialState: toLocalState(self.state.value),
      reducer: .init { localState, localAction, _ in
        isSending = true
        defer { isSending = false }
        self.send(fromLocalAction(localAction))
        localState = toLocalState(self.state.value)
        return .none
      },
      environment: (),
      dispatchToken: dispatchToken
    )
    localStore.parentCancellable = self.state
      .dropFirst()
      .sink { [weak localStore] newValue in
        guard !isSending else { return }
        localStore?.state.value = toLocalState(newValue)
      }
    return localStore
  }

  /// Scopes the store to one that exposes local state.
  ///
  /// - Parameter toLocalState: A function that transforms `State` into `LocalState`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<LocalState>(
    state toLocalState: @escaping (State) -> LocalState
  ) -> Store<LocalState, Action> {
    self.scope(state: toLocalState, action: { $0 })
  }

  /// Scopes the store to a publisher of stores of more local state and local actions.
  ///
  /// - Parameters:
  ///   - toLocalState: A function that transforms a publisher of `State` into a publisher of
  ///     `LocalState`.
  ///   - fromLocalAction: A function that transforms `LocalAction` into `Action`.
  /// - Returns: A publisher of stores with its domain (state and action) transformed.
  public func publisherScope<P: Publisher, LocalState, LocalAction>(
    state toLocalState: @escaping (AnyPublisher<State, Never>) -> P,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> AnyPublisher<Store<LocalState, LocalAction>, Never>
  where P.Output == LocalState, P.Failure == Never {
    func extractLocalState(_ state: State) -> LocalState? {
      var localState: LocalState?
      _ = toLocalState(Just(state).eraseToAnyPublisher())
        .sink { localState = $0 }
      return localState
    }

    return toLocalState(self.state.eraseToAnyPublisher())
      .map { localState in
        let localStore = Store<LocalState, LocalAction>(
          initialState: localState,
          reducer: .init { localState, localAction, _ in
            self.send(fromLocalAction(localAction))
            localState = extractLocalState(self.state.value) ?? localState
            return .none
          },
          environment: (),
          dispatchToken: self.dispatchToken
        )

        localStore.parentCancellable = self.state
          .sink { [weak localStore] state in
            guard let localStore = localStore else { return }
            localStore.state.value = extractLocalState(state) ?? localStore.state.value
          }
        return localStore
      }
      .eraseToAnyPublisher()
  }

  /// Scopes the store to a publisher of stores of more local state and local actions.
  ///
  /// - Parameter toLocalState: A function that transforms a publisher of `State` into a publisher
  ///   of `LocalState`.
  /// - Returns: A publisher of stores with its domain (state and action)
  ///   transformed.
  public func publisherScope<P: Publisher, LocalState>(
    state toLocalState: @escaping (AnyPublisher<State, Never>) -> P
  ) -> AnyPublisher<Store<LocalState, Action>, Never>
  where P.Output == LocalState, P.Failure == Never {
    self.publisherScope(state: toLocalState, action: { $0 })
  }

  func send(_ action: Action, isFromViewStore: Bool = true) {
    self.threadCheck(status: .send(action, isFromViewStore: isFromViewStore))

    self.bufferedActions.append(action)
    guard !self.isSending else { return }

    self.isSending = true
    var currentState = self.state.value
    defer {
      self.isSending = false
      self.state.value = currentState
    }

    while !self.bufferedActions.isEmpty {
      let action = self.bufferedActions.removeFirst()
      let effect = self.reducer(&currentState, action)

      var didComplete = false
      let uuid = UUID()
      let effectCancellable = effect.sink(
        receiveCompletion: { [weak self] _ in
          self?.threadCheck(status: .effectCompletion(action))
          didComplete = true
          self?.effectCancellables[uuid] = nil
        },
        receiveValue: { [weak self] action in
          self?.send(action, isFromViewStore: false)
        }
      )

      if !didComplete {
        self.effectCancellables[uuid] = effectCancellable
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
    case scope
    case send(Action, isFromViewStore: Bool)
  }

  @inline(__always)
  private func threadCheck(status: ThreadCheckStatus) {
    #if DEBUG
    
      if let dispatchToken = dispatchToken {
        if let set = DispatchQueue.getSpecific(key: storeDispatchSpecificKey),
           set.contains(dispatchToken) {
          return
        }
      } else if Thread.current.isMainThread {
        return
      }
    
      let message: String
      switch status {
      case let .effectCompletion(action):
        message = """
          An effect returned from the action "\(debugCaseOutput(action))" completed on the wrong \
          thread. Make sure to use ".receive(on:)" on any effects that execute on background \
          threads to receive their output on the same thread the store was created on.
          """

      case .scope:
        message = """
          "Store.scope" was called on the wrong thread. Make sure that "Store.scope" is always \
          called on the same thread the store was created on.
          """

      case let .send(action, isFromViewStore: true):
        message = """
          "ViewStore.send(\(debugCaseOutput(action)))" was called on the wrong thread. Make sure \
          that "ViewStore.send" is always called on the same thread the store was created on.
          """

      case let .send(action, isFromViewStore: false):
        message = """
          An effect emitted the action "\(debugCaseOutput(action))" from the wrong thread. Make \
          sure to use ".receive(on:)" on any effects that execute on background threads to receive \
          their output on the same thread the store was created on.
          """
      }

      breakpoint(
        """
        ---
        Warning:

        The store was interacted with on a thread that is different from the thread the store was \
        created on:

        \(message)

          Action sent on: \(Thread.current) instead of \(Thread.main)

        The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
        (including all of its scopes and derived view stores) must be done on the same thread.
        ---
        """
      )
    #endif
  }
}

private let storeDispatchSpecificKey = DispatchSpecificKey<Set<UUID>>()
