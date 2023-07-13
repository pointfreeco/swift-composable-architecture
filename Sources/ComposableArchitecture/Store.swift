import Combine
import Foundation

/// A store represents the runtime that powers the application. It is the object that you will pass
/// around to views that need to interact with the application.
///
/// You will typically construct a single one of these at the root of your application:
///
/// ```swift
/// @main
/// struct MyApp: App {
///   var body: some Scene {
///     WindowGroup {
///       RootView(
///         store: Store(initialState: AppFeature.State()) {
///           AppFeature()
///         }
///       )
///     }
///   }
/// }
/// ```
///
/// …and then use the ``scope(state:action:)-9iai9`` method to derive more focused stores that can be
/// passed to subviews.
///
/// ### Scoping
///
/// The most important operation defined on ``Store`` is the ``scope(state:action:)-9iai9`` method, which
/// allows you to transform a store into one that deals with child state and actions. This is
/// necessary for passing stores to subviews that only care about a small portion of the entire
/// application's domain.
///
/// For example, if an application has a tab view at its root with tabs for activity, search, and
/// profile, then we can model the domain like this:
///
/// ```swift
/// struct State {
///   var activity: Activity.State
///   var profile: Profile.State
///   var search: Search.State
/// }
///
/// enum Action {
///   case activity(Activity.Action)
///   case profile(Profile.Action)
///   case search(Search.Action)
/// }
/// ```
///
/// We can construct a view for each of these domains by applying ``scope(state:action:)-9iai9`` to a
/// store that holds onto the full app domain in order to transform it into a store for each
/// sub-domain:
///
/// ```swift
/// struct AppView: View {
///   let store: StoreOf<AppFeature>
///
///   var body: some View {
///     TabView {
///       ActivityView(
///         store: self.store.scope(state: \.activity, action: AppFeature.Action.activity)
///       )
///       .tabItem { Text("Activity") }
///
///       SearchView(
///         store: self.store.scope(state: \.search, action: AppFeature.Action.search)
///       )
///       .tabItem { Text("Search") }
///
///       ProfileView(
///         store: self.store.scope(state: \.profile, action: AppFeature.Action.profile)
///       )
///       .tabItem { Text("Profile") }
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
/// constructed via the initializer ``init(initialState:reducer:prepareDependencies:)`` are assumed
/// to run only on the main thread, and so a check is executed immediately to make sure that is the
/// case. Further, all actions sent to the store and all scopes (see ``scope(state:action:)-9iai9``) of
/// the store are also checked to make sure that work is performed on the main thread.
public final class Store<State, Action> {
  private var bufferedActions: [Action] = []
  @_spi(Internals) public var effectCancellables: [UUID: AnyCancellable] = [:]
  var _isInvalidated = { false }
  private var isSending = false
  var parentCancellable: AnyCancellable?
  private let reducer: any ReducerProtocol<State, Action>
  @_spi(Internals) public var state: CurrentValueSubject<State, Never>
  #if DEBUG
    private let mainThreadChecksEnabled: Bool
  #endif

  /// Initializes a store from an initial state and a reducer.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the application in.
  ///   - reducer: The reducer that powers the business logic of the application.
  ///   - prepareDependencies: A closure that can be used to override dependencies that will be accessed
  ///     by the reducer.
  public convenience init<R: ReducerProtocol>(
    initialState: @autoclosure () -> R.State,
    @ReducerBuilder<State, Action> reducer: () -> R,
    withDependencies prepareDependencies: ((inout DependencyValues) -> Void)? = nil
  ) where R.State == State, R.Action == Action {
    if let prepareDependencies = prepareDependencies {
      let (initialState, reducer) = withDependencies(prepareDependencies) {
        (initialState(), reducer())
      }
      self.init(
        initialState: initialState,
        reducer: reducer.transformDependency(\.self, transform: prepareDependencies),
        mainThreadChecksEnabled: true
      )
    } else {
      self.init(
        initialState: initialState(),
        reducer: reducer(),
        mainThreadChecksEnabled: true
      )
    }
  }

  /// Calls the given closure with the current state of the store.
  ///
  /// A lightweight way of accessing store state when no view store is available and state does not
  /// need to be observed, _e.g._ by a SwiftUI view. If a view store is available, prefer
  /// ``ViewStore/state-swift.property``.
  ///
  /// - Parameter body: A closure that takes the current state of the store as its sole argument. If
  ///   the closure has a return value, that value is also used as the return value of the
  ///   `withState` method. The state argument reflects the current state of the store only for the
  ///   duration of the closure's execution, and is not observable over time, _e.g._ by SwiftUI. If
  ///   you want to observe store state in a view, use a ``ViewStore`` instead.
  /// - Returns: The return value, if any, of the `body` closure.
  public func withState<R>(_ body: (State) -> R) -> R {
    body(self.state.value)
  }

  /// Sends an action to the store.
  ///
  /// A lightweight way to send actions to the store when no view store is available. If a view
  /// store is available, prefer ``ViewStore/send(_:)``.
  ///
  /// - Parameter action: An action.
  public func send(_ action: Action) {
    _ = self.send(action, originatingFrom: nil)
  }

  /// Scopes the store to one that exposes child state and actions.
  ///
  /// This can be useful for deriving new stores to hand to child views in an application. For
  /// example:
  ///
  /// ```swift
  /// // Application state made from child states.
  /// struct AppFeature: ReducerProtocol {
  ///   struct State {
  ///     var login: Login.State
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case login(Login.Action)
  ///     // ...
  ///   }
  ///
  /// // A store that runs the entire application.
  /// let store = Store(initialState: AppFeature.State()) {
  ///   AppFeature()
  /// }
  ///
  /// // Construct a login view by scoping the store
  /// // to one that works with only login domain.
  /// LoginView(
  ///   store: store.scope(
  ///     state: \.login,
  ///     action: AppFeature.Action.login
  ///   )
  /// )
  /// ```
  ///
  /// Scoping in this fashion allows you to better modularize your application. In this case,
  /// `LoginView` could be extracted to a module that has no access to `AppFeature.State` or
  /// `AppFeature.Action`.
  ///
  /// Scoping also gives a view the opportunity to focus on just the state and actions it cares
  /// about, even if its feature domain is larger.
  ///
  /// For example, the above login domain could model a two screen login flow: a login form followed
  /// by a two-factor authentication screen. The second screen's domain might be nested in the
  /// first:
  ///
  /// ```swift
  /// struct Login: ReducerProtocol {
  ///   struct State: Equatable {
  ///     var email = ""
  ///     var password = ""
  ///     var twoFactorAuth: TwoFactorAuthState?
  ///   }
  ///   enum Action: Equatable {
  ///     case emailChanged(String)
  ///     case loginButtonTapped
  ///     case loginResponse(Result<TwoFactorAuthState, LoginError>)
  ///     case passwordChanged(String)
  ///     case twoFactorAuth(TwoFactorAuthAction)
  ///   }
  ///   // ...
  /// }
  /// ```
  ///
  /// The login view holds onto a store of this domain:
  ///
  /// ```swift
  /// struct LoginView: View {
  ///   let store: StoreOf<Login>
  ///
  ///   var body: some View { /* ... */ }
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
  ///   struct ViewState: Equatable {
  ///     var email: String
  ///     var password: String
  ///   }
  ///
  ///   enum ViewAction: Equatable {
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
  /// extension Login.State {
  ///   var view: LoginView.ViewState {
  ///     .init(email: self.email, password: self.password)
  ///   }
  /// }
  ///
  /// extension LoginView.ViewAction {
  ///   var feature: Login.Action {
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
  ///      // ...
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
    self.scope(state: toChildState, action: fromChildAction, removeDuplicates: nil)
  }

  /// Scopes the store to one that exposes child state and actions.
  ///
  /// This is a special overload of ``scope(state:action:)-9iai9`` that works specifically for
  /// ``PresentationState`` and ``PresentationAction``.
  ///
  /// - Parameters:
  ///   - toChildState: A function that transforms `State` into ``PresentationState``.
  ///   - fromChildAction: A function that transforms ``PresentationAction`` into `Action`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (State) -> PresentationState<ChildState>,
    action fromChildAction: @escaping (PresentationAction<ChildAction>) -> Action
  ) -> Store<PresentationState<ChildState>, PresentationAction<ChildAction>> {
    self.scope(
      state: toChildState,
      action: fromChildAction,
      removeDuplicates: {
        $0.sharesStorage(with: $1)
      }
    )
  }

  func scope<ChildState, ChildAction>(
    state toChildState: @escaping (State) -> ChildState,
    action fromChildAction: @escaping (ChildAction) -> Action,
    removeDuplicates isDuplicate: ((ChildState, ChildState) -> Bool)?
  ) -> Store<ChildState, ChildAction> {
    self.threadCheck(status: .scope)
    return self.reducer.rescope(
      self,
      state: toChildState,
      action: { fromChildAction($1) },
      removeDuplicates: isDuplicate
    )
  }

  func invalidate(_ isInvalid: @escaping (State) -> Bool) -> Store {
    self.threadCheck(status: .scope)
    let store: Store = self.reducer.rescope(
      self,
      state: { $0 },
      action: { state, action in isInvalid(state) && BindingLocal.isActive ? nil : action },
      removeDuplicates: { isInvalid($0) && isInvalid($1) }
    )
    store._isInvalidated = { self._isInvalidated() || isInvalid(self.state.value) }
    return store
  }

  @_spi(Internals)
  public func send(
    _ action: Action,
    originatingFrom originatingAction: Action?
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
      self.state.value = currentState
      self.isSending = false
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
      let effect = self.reducer.reduce(into: &currentState, action: action)

      switch effect.operation {
      case .none:
        break
      case let .publisher(publisher):
        var didComplete = false
        let boxedTask = Box<Task<Void, Never>?>(wrappedValue: nil)
        let uuid = UUID()
        let effectCancellable = withEscapedDependencies { continuation in
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
                if let task = continuation.yield({
                  self.send(effectAction, originatingFrom: action)
                }) {
                  tasks.wrappedValue.append(task)
                }
              }
            )
        }

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
        withEscapedDependencies { continuation in
          tasks.wrappedValue.append(
            Task(priority: priority) { @MainActor in
              #if DEBUG
                let isCompleted = LockIsolated(false)
                defer { isCompleted.setValue(true) }
              #endif
              await operation(
                Send { effectAction in
                  #if DEBUG
                    if isCompleted.value {
                      runtimeWarn(
                        """
                        An action was sent from a completed effect:

                          Action:
                            \(debugCaseOutput(effectAction))

                          Effect returned from:
                            \(debugCaseOutput(action))

                        Avoid sending actions using the 'send' argument from 'EffectTask.run' after \
                        the effect has completed. This can happen if you escape the 'send' argument in \
                        an unstructured context.

                        To fix this, make sure that your 'run' closure does not return until you're \
                        done calling 'send'.
                        """
                      )
                    }
                  #endif
                  if let task = continuation.yield({
                    self.send(effectAction, originatingFrom: action)
                  }) {
                    tasks.wrappedValue.append(task)
                  }
                }
              )
            }
          )
        }
      }
    }

    guard !tasks.wrappedValue.isEmpty else { return nil }
    return Task {
      await withTaskCancellationHandler {
        var index = tasks.wrappedValue.startIndex
        while index < tasks.wrappedValue.endIndex {
          defer { index += 1 }
          await tasks.wrappedValue[index].value
        }
      } onCancel: {
        var index = tasks.wrappedValue.startIndex
        while index < tasks.wrappedValue.endIndex {
          defer { index += 1 }
          tasks.wrappedValue[index].cancel()
        }
      }
    }
  }

  /// Returns a "stateless" store by erasing state to `Void`.
  public var stateless: Store<Void, Action> {
    self.scope(state: { _ in () }, action: { $0 })
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
        runtimeWarn(
          """
          An effect completed on a non-main thread. …

            Effect returned from:
              \(debugCaseOutput(action))

          Make sure to use ".receive(on:)" on any effects that execute on background threads to \
          receive their output on the main thread.

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """
        )

      case .`init`:
        runtimeWarn(
          """
          A store initialized on a non-main thread. …

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """
        )

      case .scope:
        runtimeWarn(
          """
          "Store.scope" was called on a non-main thread. …

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """
        )

      case let .send(action, originatingAction: nil):
        runtimeWarn(
          """
          "ViewStore.send" was called on a non-main thread with: \(debugCaseOutput(action)) …

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """
        )

      case let .send(action, originatingAction: .some(originatingAction)):
        runtimeWarn(
          """
          An effect published an action on a non-main thread. …

            Effect published:
              \(debugCaseOutput(action))

            Effect returned from:
              \(debugCaseOutput(originatingAction))

          Make sure to use ".receive(on:)" on any effects that execute on background threads to \
          receive their output on the main thread.

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """
        )
      }
    #endif
  }

  init<R: ReducerProtocol>(
    initialState: R.State,
    reducer: R,
    mainThreadChecksEnabled: Bool
  ) where R.State == State, R.Action == Action {
    self.state = CurrentValueSubject(initialState)
    self.reducer = reducer
    #if DEBUG
      self.mainThreadChecksEnabled = mainThreadChecksEnabled
    #endif
    self.threadCheck(status: .`init`)
  }
}

/// A convenience type alias for referring to a store of a given reducer's domain.
///
/// Instead of specifying two generics:
///
/// ```swift
/// let store: Store<Feature.State, Feature.Action>
/// ```
///
/// You can specify a single generic:
///
/// ```swift
/// let store: StoreOf<Feature>
/// ```
public typealias StoreOf<R: ReducerProtocol> = Store<R.State, R.Action>

extension ReducerProtocol {
  fileprivate func rescope<ChildState, ChildAction>(
    _ store: Store<State, Action>,
    state toChildState: @escaping (State) -> ChildState,
    action fromChildAction: @escaping (ChildState, ChildAction) -> Action?,
    removeDuplicates isDuplicate: ((ChildState, ChildState) -> Bool)?
  ) -> Store<ChildState, ChildAction> {
    (self as? any AnyScopedReducer ?? ScopedReducer(rootStore: store)).rescope(
      store,
      state: toChildState,
      action: fromChildAction,
      removeDuplicates: isDuplicate
    )
  }
}

private final class ScopedReducer<
  RootState, RootAction, State, Action
>: ReducerProtocol {
  let rootStore: Store<RootState, RootAction>
  let toScopedState: (RootState) -> State
  private let parentStores: [Any]
  let fromScopedAction: (State, Action) -> RootAction?
  private(set) var isSending = false

  @inlinable
  init(rootStore: Store<RootState, RootAction>)
  where RootState == State, RootAction == Action {
    self.rootStore = rootStore
    self.toScopedState = { $0 }
    self.parentStores = []
    self.fromScopedAction = { $1 }
  }

  @inlinable
  init(
    rootStore: Store<RootState, RootAction>,
    state toScopedState: @escaping (RootState) -> State,
    action fromScopedAction: @escaping (State, Action) -> RootAction?,
    parentStores: [Any]
  ) {
    self.rootStore = rootStore
    self.toScopedState = toScopedState
    self.fromScopedAction = fromScopedAction
    self.parentStores = parentStores
  }

  @inlinable
  func reduce(
    into state: inout State, action: Action
  ) -> EffectTask<Action> {
    self.isSending = true
    defer {
      state = self.toScopedState(self.rootStore.state.value)
      self.isSending = false
    }
    if let action = self.fromScopedAction(state, action),
      let task = self.rootStore.send(action, originatingFrom: nil)
    {
      return .run { _ in await task.cancellableValue }
    } else {
      return .none
    }
  }
}

protocol AnyScopedReducer {
  func rescope<ScopedState, ScopedAction, RescopedState, RescopedAction>(
    _ store: Store<ScopedState, ScopedAction>,
    state toRescopedState: @escaping (ScopedState) -> RescopedState,
    action fromRescopedAction: @escaping (RescopedState, RescopedAction) -> ScopedAction?,
    removeDuplicates isDuplicate: ((RescopedState, RescopedState) -> Bool)?
  ) -> Store<RescopedState, RescopedAction>
}

extension ScopedReducer: AnyScopedReducer {
  @inlinable
  func rescope<ScopedState, ScopedAction, RescopedState, RescopedAction>(
    _ store: Store<ScopedState, ScopedAction>,
    state toRescopedState: @escaping (ScopedState) -> RescopedState,
    action fromRescopedAction: @escaping (RescopedState, RescopedAction) -> ScopedAction?,
    removeDuplicates isDuplicate: ((RescopedState, RescopedState) -> Bool)?
  ) -> Store<RescopedState, RescopedAction> {
    let fromScopedAction = self.fromScopedAction as! (ScopedState, ScopedAction) -> RootAction?
    let reducer = ScopedReducer<RootState, RootAction, RescopedState, RescopedAction>(
      rootStore: self.rootStore,
      state: { _ in toRescopedState(store.state.value) },
      action: { fromRescopedAction($0, $1).flatMap { fromScopedAction(store.state.value, $0) } },
      parentStores: self.parentStores + [store]
    )
    let childStore = Store<RescopedState, RescopedAction>(
      initialState: toRescopedState(store.state.value),
      reducer: reducer
    )
    childStore._isInvalidated = store._isInvalidated
    childStore.parentCancellable = store.state
      .dropFirst()
      .sink { [weak childStore] newValue in
        guard !reducer.isSending, let childStore = childStore else { return }
        let newValue = toRescopedState(newValue)
        guard isDuplicate.map({ !$0(childStore.state.value, newValue) }) ?? true else {
          return
        }
        childStore.state.value = newValue
      }
    return childStore
  }
}
