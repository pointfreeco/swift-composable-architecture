import Combine
import Foundation

/// A store represents the runtime that powers the application. It is the object that you will pass
/// around to views that need to interact with the application.
///
/// You will typically construct a single one of these at the root of your application, and then use
/// the `scope` method to derive more focused stores that can be passed to subviews.
public final class Store<State, Action> {
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
    var bufferedActions: [Action] = []
    let effectCancellables = Ref<[UUID: AnyCancellable]>(wrappedValue: [:])
    var isSending = false
    var send: ((Action) -> Void)!
    let state = CurrentValueSubject<State, Never>(initialState)
    var synchronousActionsToSend: [Action] = []
    send = { action in
      if !isSending {
        synchronousActionsToSend.append(action)
      } else {
        bufferedActions.append(action)
        return
      }

      var currentState = state.value
      while !synchronousActionsToSend.isEmpty || !bufferedActions.isEmpty {
        let action =
          !synchronousActionsToSend.isEmpty
          ? synchronousActionsToSend.removeFirst()
          : bufferedActions.removeFirst()

        isSending = true
        let effect = reducer(&state.value, action, environment)
        isSending = false

        var didComplete = false
        let uuid = UUID()

        var isProcessingEffects = true
        let effectCancellable = effect.sink(
          receiveCompletion: { _ in
            didComplete = true
            effectCancellables[uuid] = nil
          },
          receiveValue: { action in
            if isProcessingEffects {
              synchronousActionsToSend.append(action)
            } else {
              send(action)
            }
          }
        )
        isProcessingEffects = false

        if !didComplete {
          effectCancellables[uuid] = effectCancellable
        }
      }
    }
    self.init(
      effectCancellables: effectCancellables,
      send: send,
      state: .init(
        _output: { state.value },
        upstream: state
//          .shareReplay(1)
          .share()
          .eraseToAnyPublisher()
      )
    )
  }

  /// Scopes the store to one that exposes local state and actions.
  ///
  /// This can be useful for deriving new stores to hand to child views in an application. For
  /// example:
  ///
  ///     // Application state made from local states.
  ///     struct AppState { var login: LoginState, ... }
  ///     struct AppAction { case login(LoginAction), ... }
  ///
  ///     // A store that runs the entire application.
  ///     let store = Store(
  ///       initialState: AppState(),
  ///       reducer: appReducer,
  ///       environment: AppEnvironment()
  ///     )
  ///
  ///     // Construct a login view by scoping the store to one that works with only login domain.
  ///     LoginView(
  ///       store: store.scope(
  ///         state: { $0.login },
  ///         action: { AppAction.login($0) }
  ///       )
  ///     )
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
  ///     struct LoginState: Equatable {
  ///       var email = ""
  ///       var password = ""
  ///       var twoFactorAuth: TwoFactorAuthState?
  ///     }
  ///
  ///     enum LoginAction: Equatable {
  ///       case emailChanged(String)
  ///       case loginButtonTapped
  ///       case loginResponse(Result<TwoFactorAuthState, LoginError>)
  ///       case passwordChanged(String)
  ///       case twoFactorAuth(TwoFactorAuthAction)
  ///     }
  ///
  /// The login view holds onto a store of this domain:
  ///
  ///     struct LoginView: View {
  ///       let store: Store<LoginState, LoginAction>
  ///
  ///       var body: some View { ... }
  ///     }
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
  ///     extension LoginView {
  ///       struct State: Equatable {
  ///         var email: String
  ///         var password: String
  ///       }
  ///
  ///       enum Action: Equatable {
  ///         case emailChanged(String)
  ///         case loginButtonTapped
  ///         case passwordChanged(String)
  ///       }
  ///     }
  ///
  /// One can also introduce a couple helpers that transform feature state into view state and
  /// transform view actions into feature actions.
  ///
  ///     extension LoginState {
  ///       var view: LoginView.State {
  ///         .init(email: self.email, password: self.password)
  ///       }
  ///     }
  ///
  ///     extension LoginView.Action {
  ///       var feature: LoginAction {
  ///         switch self {
  ///         case let .emailChanged(email)
  ///           return .emailChanged(email)
  ///         case .loginButtonTapped:
  ///           return .loginButtonTapped
  ///         case let .passwordChanged(password)
  ///           return .passwordChanged(password)
  ///         }
  ///       }
  ///     }
  ///
  /// With these helpers defined, `LoginView` can now scope its store's feature domain into its view
  /// domain:
  ///
  ///     var body: some View {
  ///       WithViewStore(
  ///         self.store.scope(state: { $0.view }, action: { $0.feature })
  ///       ) { viewStore in
  ///         ...
  ///       }
  ///     }
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
    let localStore = Store<LocalState, LocalAction>(
      effectCancellables: self.$effectCancellables,
      send: { self.send(fromLocalAction($0)) },
      state: self.state.map(toLocalState)
    )
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

  /// Returns a "stateless" store by erasing state to `Void`.
  public var stateless: Store<Void, Action> {
    self.scope(state: { _ in () })
  }

  /// Returns an "actionless" store by erasing action to `Never`.
  public var actionless: Store<State, Never> {
    func absurd<A>(_ never: Never) -> A {}
    return self.scope(state: { $0 }, action: absurd)
  }

  @Ref var effectCancellables: [UUID: AnyCancellable]
  let send: (Action) -> Void
  var state: StorePublisher<State>

  init(
    effectCancellables: Ref<[UUID: AnyCancellable]>,
    send: @escaping (Action) -> Void,
    state: StorePublisher<State>
  ) {
    self.state = state
    self.send = send
    self._effectCancellables = effectCancellables
  }
}

/// A publisher of store state.
@dynamicMemberLookup
public struct StorePublisher<State>: Publisher {
  public typealias Output = State
  public typealias Failure = Never

  let _output: () -> State
  public let upstream: AnyPublisher<State, Never>

  var value: State {
    self._output()
  }

  public func receive<S>(subscriber: S)
  where S: Subscriber, Output == S.Input, Failure == S.Failure {
    self.upstream.subscribe(subscriber)
  }

  public func map<NewOutput>(
    _ transform: @escaping (Output) -> NewOutput
  ) -> StorePublisher<NewOutput> {
    var memoized: NewOutput?
    let memoizedTransform: (Output) -> NewOutput = { output in
      if let memoized = memoized { return memoized }
      let newOutput = transform(output)
      memoized = newOutput
      return newOutput
    }
    let _output = { memoizedTransform(self._output()) }
    return .init(
      _output: _output,
      upstream: self.upstream
        .handleEvents(receiveOutput: { _ in memoized = nil })
        .map(memoizedTransform)
//        .shareReplay(1)
        .share()
        .eraseToAnyPublisher()
    )
  }

  /// Returns the resulting publisher of a given key path.
  public subscript<NewOutput>(
    dynamicMember keyPath: KeyPath<Output, NewOutput>
  ) -> StorePublisher<NewOutput>
  where NewOutput: Equatable {
    .init(
      _output: { self._output()[keyPath: keyPath] },
      upstream: self.upstream
        .map { $0[keyPath: keyPath] }
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }
}
