import Combine
import Foundation

/// A store represents the runtime that powers the application. It is the object that you will pass
/// around to views that need to interact with the application.
///
/// You will typically construct a single one of these at the root of your application, and then use
/// the ``scope(state:action:scopeIdentifier:)`` method to derive more focused stores that can be
/// passed to subviews:
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
/// The most important operation defined on ``Store`` is the
/// ``scope(state:action:scopeIdentifier:)`` method, which allows you to transform a store into one
/// that deals with local state and actions. This is necessary for passing stores to subviews that
/// only care about a small portion of the entire application's domain.
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
/// We can construct a view for each of these domains by applying
/// ``scope(state:action:scopeIdentifier:)`` to a store that holds onto the full app domain in order
/// to transform it into a store for each sub-domain:
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
/// (including all of its scopes and derived ``ViewStore``s) must be done on the same thread the
/// store was created on. Further, if the store is powering a SwiftUI or UIKit view, as is
/// customary, then all interactions must be done on the _main_ thread.
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
/// #### Thread safety checks
///
/// The store performs some basic thread safety checks in order to help catch mistakes. Stores
/// constructed via the initializer ``Store/init(initialState:reducer:environment:)`` are assumed
/// to run only on the main thread, and so a check is executed immediately to make sure that is the
/// case. Further, all actions sent to the store and all scopes (see
/// ``Store/scope(state:action:scopeIdentifier:)``) of the store are also checked to make sure that
/// work is performed on the main thread.
///
/// If you need a store that runs on a non-main thread, which should be very rare and you should
/// have a very good reason to do so, then you can construct a store via the
/// ``Store/unchecked(initialState:reducer:environment:)`` static method to opt out of all main
/// thread checks.
///
/// ---
///
/// See also: ``ViewStore`` to understand how one observes changes to the state in a ``Store`` and
/// sends user actions.
public final class Store<State, Action> {
  private var bufferedActions: [Action] = []
  var effectCancellables: [UUID: AnyCancellable] = [:]
  private var isSending = false
  var parentCancellable: AnyCancellable?
  private let reducer: (inout State, Action) -> Effect<Action, Never>
  private let scopeCache = WeakCache<ScopeIdentifier, AnyObject>()
  let viewStoresCache = WeakCache<ScopeIdentifier, AnyObject>()
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

  /// Initializes a store from an initial state, a reducer, and an environment, and the main thread
  /// check is disabled for all interactions with this store.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the application in.
  ///   - reducer: The reducer that powers the business logic of the application.
  ///   - environment: The environment of dependencies for the application.
  public static func unchecked<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) -> Self {
    Self(
      initialState: initialState,
      reducer: reducer,
      environment: environment,
      mainThreadChecksEnabled: false
    )
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
    action fromLocalAction: @escaping (LocalAction) -> Action,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) -> Store<LocalState, LocalAction> {
    scope(
      state: toLocalState,
      action: fromLocalAction,
      scopeIdentifier: SharedStoreConfiguration.shouldInferScopeIdentifiers
        ? ScopeIdentifier(file: file, line: line, column: column)
        : nil
    )
  }
  
  public func scope<LocalState, LocalAction>(
    state toLocalState: @escaping (State) -> LocalState,
    action fromLocalAction: @escaping (LocalAction) -> Action,
    scopeIdentifier: ScopeIdentifier?
  ) -> Store<LocalState, LocalAction> {
    self.threadCheck(status: .scope)
    
    if let scopeIdentifier = scopeIdentifier, let scoped = scopeCache[scopeIdentifier] {
      guard let scoped = scoped as? Store<LocalState, LocalAction> else {
        fatalError("Tried to reuse the wrong store")
      }
      #if DEBUG
      if SharedStoreConfiguration.printOptions.contains(.reusableStore) {
          print("Reusing Store<\(LocalState.self), \(LocalAction.self)> with id: \(scopeIdentifier)")
        }
      #endif
      return scoped
    } else if scopeIdentifier == nil {
      #if DEBUG
       if SharedStoreConfiguration.printOptions.contains(.nonReusableStore) {
          print("Initializing non-reusable Store<\(LocalState.self), \(LocalAction.self)>")
        }
      #endif
    }

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
      environment: ()
    )
    localStore.parentCancellable = self.state
      .dropFirst()
      .sink { [weak localStore] newValue in
        guard !isSending else { return }
        localStore?.state.value = toLocalState(newValue)
      }
    
    if let scopeIdentifier = scopeIdentifier {
    #if DEBUG
      if SharedStoreConfiguration.printOptions.contains(.reusableStore) {
        print("Caching Store<\(LocalState.self), \(LocalAction.self)> with id: \(scopeIdentifier)")
      }
    #endif
      scopeCache[scopeIdentifier] = localStore
    }
    
    return localStore
  }

  /// Scopes the store to one that exposes local state.
  ///
  /// - Parameter toLocalState: A function that transforms `State` into `LocalState`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<LocalState>(
    state toLocalState: @escaping (State) -> LocalState,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) -> Store<LocalState, Action> {
    self.scope(
      state: toLocalState,
      action: { $0 },
      scopeIdentifier: SharedStoreConfiguration.shouldInferScopeIdentifiers
      ? ScopeIdentifier(file: file, line: line, column: column)
      : nil
    )
  }
  
  public func scope<LocalState>(
    state toLocalState: @escaping (State) -> LocalState,
    scopeIdentifier: ScopeIdentifier?
  ) -> Store<LocalState, Action> {
    self.scope(
      state: toLocalState,
      action: { $0 },
      scopeIdentifier: scopeIdentifier
    )
  }
  
  func send(_ action: Action, originatingFrom originatingAction: Action? = nil) {
    self.threadCheck(status: .send(action, originatingAction: originatingAction))

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
        receiveValue: { [weak self] effectAction in
          self?.send(effectAction, originatingFrom: action)
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
    case `init`
    case scope
    case send(Action, originatingAction: Action?)
  }

  @inline(__always)
  private func threadCheck(status: ThreadCheckStatus) {
    #if DEBUG
      guard self.mainThreadChecksEnabled && !Thread.isMainThread
      else { return }

      let message: String
      switch status {
      case let .effectCompletion(action):
        message = """
          An effect returned from the action "\(debugCaseOutput(action))" completed on a non-main \
          thread. Make sure to use ".receive(on:)" on any effects that execute on background \
          threads to receive their output on the main thread, or create this store via \
          "Store.unchecked" to disable the main thread checker.
          """

      case .`init`:
        message = """
          "Store.init" was called on a non-main thread. Make sure that stores are initialized on \
          the main thread, or create this store via "Store.unchecked" to disable the main thread \
          checker.
          """

      case .scope:
        message = """
          "Store.scope" was called on a non-main thread. Make sure that "Store.scope" is always \
          called on the main thread, or create this store via "Store.unchecked" to disable the \
          main thread checker.
          """

      case let .send(action, originatingAction: nil):
        message = """
          "ViewStore.send(\(debugCaseOutput(action)))" was called on a non-main thread. Make sure \
          that "ViewStore.send" is always called on the main thread, or create this store via \
          "Store.unchecked" to disable the main thread checker.
          """

      case let .send(action, originatingAction: .some(originatingAction)):
        message = """
          An effect returned from "\(debugCaseOutput(originatingAction))" emitted the action \
          "\(debugCaseOutput(action))" on a non-main thread. Make sure to use ".receive(on:)" on \
          any effects that execute on background threads to receive their output on the main \
          thread, or create this store via "Store.unchecked" to disable the main thread checker.
          """
      }

      breakpoint(
        """
        ---
        Warning:

        A store created on the main thread was interacted with on a non-main thread:

          Thread: \(Thread.current)

        \(message)

        The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
        (including all of its scopes and derived view stores) must be done on the main thread.
        ---
        """
      )
    #endif
  }

  private init<Environment>(
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

public enum SharedStoreConfiguration {
  public struct PrintOptions: RawRepresentable, OptionSet {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    static let reusableStore = PrintOptions(rawValue: 1 << 0)
    static let reusableViewStore = PrintOptions(rawValue: 1 << 1)
    
    static let nonReusableStore = PrintOptions(rawValue: 1 << 2)
    static let nonReusableViewStore = PrintOptions(rawValue: 1 << 3)
    
    public static let store: PrintOptions = [.reusableStore, .nonReusableStore]
    public static let viewStore: PrintOptions = [.reusableViewStore, .nonReusableViewStore]
    public static let nonReusable: PrintOptions = [.nonReusableStore, .nonReusableViewStore]
    public static let all: PrintOptions = [.store, .viewStore]
  }
  
  public static var shouldInferScopeIdentifiers = true
  public static var printOptions: PrintOptions = .nonReusable
}

public struct ScopeIdentifier: Hashable {
  let id: AnyHashable
  #if DEBUG
    public var description: String
  #endif
  public init<ID>(_ id: ID) where ID: Hashable {
    self.id = id
    #if DEBUG
      self.description = String(describing: id)
    #endif
  }

  public init(file: StaticString, line: UInt, column: UInt? = nil) {
    self.id = "\(file)-l.\(line)c.\(column ?? 0)"
    #if DEBUG
      self.description = "\(file)-l.\(line)c.\(column ?? 0)"
    #endif
  }

  public init<Element1, Element2>(_ e1: Element1, _ e2: Element2)
    where Element1: Hashable, Element2: Hashable {
    self.id = [e1, e2] as [AnyHashable]
    #if DEBUG
      self.description = "\(String(describing: e1))-\(String(describing: e2))"
    #endif
  }
}

#if DEBUG
  extension ScopeIdentifier: CustomStringConvertible {}
#endif

extension ScopeIdentifier: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) {
    self.id = value
    #if DEBUG
      self.description = value
    #endif
  }
}

extension ScopeIdentifier: ExpressibleByStringInterpolation {
  public init(stringInterpolation: DefaultStringInterpolation) {
    self.id = "\(stringInterpolation)"
    #if DEBUG
      self.description = "\(stringInterpolation)"
    #endif
  }
}
