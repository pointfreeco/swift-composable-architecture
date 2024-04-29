import Combine
import Foundation
import SwiftUI

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
/// …and then use the ``scope(state:action:)-90255`` method to derive more focused stores that can be
/// passed to subviews.
///
/// ### Scoping
///
/// The most important operation defined on ``Store`` is the ``scope(state:action:)-90255`` method,
/// which allows you to transform a store into one that deals with child state and actions. This is
/// necessary for passing stores to subviews that only care about a small portion of the entire
/// application's domain.
///
/// For example, if an application has a tab view at its root with tabs for activity, search, and
/// profile, then we can model the domain like this:
///
/// ```swift
/// @Reducer
/// struct AppFeature {
///   struct State {
///     var activity: Activity.State
///     var profile: Profile.State
///     var search: Search.State
///   }
///
///   enum Action {
///     case activity(Activity.Action)
///     case profile(Profile.Action)
///     case search(Search.Action)
///   }
///
///   // ...
/// }
/// ```
///
/// We can construct a view for each of these domains by applying ``scope(state:action:)-90255`` to
/// a store that holds onto the full app domain in order to transform it into a store for each
/// subdomain:
///
/// ```swift
/// struct AppView: View {
///   let store: StoreOf<AppFeature>
///
///   var body: some View {
///     TabView {
///       ActivityView(
///         store: store.scope(state: \.activity, action: \.activity)
///       )
///       .tabItem { Text("Activity") }
///
///       SearchView(
///         store: store.scope(state: \.search, action: \.search)
///       )
///       .tabItem { Text("Search") }
///
///       ProfileView(
///         store: store.scope(state: \.profile, action: \.profile)
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
/// (including all of its child stores) must be done on the same thread the store was created on.
/// Further, if the store is powering a SwiftUI or UIKit view, as is customary, then all
/// interactions must be done on the _main_ thread.
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
/// constructed via the initializer ``init(initialState:reducer:withDependencies:)`` are assumed
/// to run only on the main thread, and so a check is executed immediately to make sure that is the
/// case. Further, all actions sent to the store and all scopes (see ``scope(state:action:)-90255``)
/// of the store are also checked to make sure that work is performed on the main thread.
@dynamicMemberLookup
public final class Store<State, Action> {
  var canCacheChildren = true
  private var children: [ScopeID<State, Action>: AnyObject] = [:]
  var _isInvalidated = { false }

  @_spi(Internals) public let rootStore: RootStore
  private let toState: PartialToState<State>
  private let fromAction: (Action) -> Any

  #if canImport(Perception)
    #if !os(visionOS)
      let _$observationRegistrar = PerceptionRegistrar(
        isPerceptionCheckingEnabled: _isStorePerceptionCheckingEnabled
      )
    #else
      let _$observationRegistrar = ObservationRegistrar()
    #endif
    private var parentCancellable: AnyCancellable?
  #else
    // NB: This dynamic member lookup is needed to support pre-Observation (<5.9) versions of Swift.
    @_disfavoredOverload
    private subscript(dynamicMember keyPath: KeyPath<State, Never>) -> Never {
      self.currentState[keyPath: keyPath]
    }
  #endif

  /// Initializes a store from an initial state and a reducer.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the application in.
  ///   - reducer: The reducer that powers the business logic of the application.
  ///   - prepareDependencies: A closure that can be used to override dependencies that will be accessed
  ///     by the reducer.
  public convenience init<R: Reducer>(
    initialState: @autoclosure () -> R.State,
    @ReducerBuilder<State, Action> reducer: () -> R,
    withDependencies prepareDependencies: ((inout DependencyValues) -> Void)? = nil
  ) where R.State == State, R.Action == Action {
    if let prepareDependencies {
      let (initialState, reducer, dependencies) = withDependencies(prepareDependencies) {
        @Dependency(\.self) var dependencies
        return (initialState(), reducer(), dependencies)
      }
      self.init(
        initialState: initialState,
        reducer: reducer.dependency(\.self, dependencies)
      )
    } else {
      self.init(
        initialState: initialState(),
        reducer: reducer()
      )
    }
  }

  init() {
    self._isInvalidated = { true }
    self.rootStore = RootStore(initialState: (), reducer: EmptyReducer<Void, Never>())
    self.toState = .keyPath(\State.self)
    self.fromAction = { $0 }
  }

  deinit {
    Logger.shared.log("\(storeTypeName(of: self)).deinit")
  }

  /// Calls the given closure with a snapshot of the current state of the store.
  ///
  /// A lightweight way of accessing store state when state is not observable and ``state-1qxwl`` is
  /// unavailable.
  ///
  /// - Parameter body: A closure that takes the current state of the store as its sole argument. If
  ///   the closure has a return value, that value is also used as the return value of the
  ///   `withState` method. The state argument reflects the current state of the store only for the
  ///   duration of the closure's execution, and is only observable over time, _e.g._ by SwiftUI, if
  ///   it conforms to ``ObservableState``.
  /// - Returns: The return value, if any, of the `body` closure.
  public func withState<R>(_ body: (_ state: State) -> R) -> R {
    #if canImport(Perception)
      _withoutPerceptionChecking { body(self.currentState) }
    #else
      body(self.currentState)
    #endif
  }

  /// Sends an action to the store.
  ///
  /// This method returns a ``StoreTask``, which represents the lifecycle of the effect started from
  /// sending an action. You can use this value to tie the effect's lifecycle _and_ cancellation to
  /// an asynchronous context, such as SwiftUI's `task` view modifier:
  ///
  /// ```swift
  /// .task { await store.send(.task).finish() }
  /// ```
  ///
  /// > Important: The ``Store`` is not thread safe and you should only send actions to it from the
  /// > main thread. If you want to send actions on background threads due to the fact that the
  /// > reducer is performing computationally expensive work, then a better way to handle this is to
  /// > wrap that work in an ``Effect`` that is performed on a background thread so that the
  /// > result can be fed back into the store.
  ///
  /// - Parameter action: An action.
  /// - Returns: A ``StoreTask`` that represents the lifecycle of the effect executed when
  ///   sending the action.
  @discardableResult
  public func send(_ action: Action) -> StoreTask {
    .init(rawValue: self.send(action, originatingFrom: nil))
  }

  /// Sends an action to the store with a given animation.
  ///
  /// See ``Store/send(_:)`` for more info.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - animation: An animation.
  @discardableResult
  public func send(_ action: Action, animation: Animation?) -> StoreTask {
    send(action, transaction: Transaction(animation: animation))
  }

  /// Sends an action to the store with a given transaction.
  ///
  /// See ``Store/send(_:)`` for more info.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - transaction: A transaction.
  @discardableResult
  public func send(_ action: Action, transaction: Transaction) -> StoreTask {
    withTransaction(transaction) {
      .init(rawValue: self.send(action, originatingFrom: nil))
    }
  }

  /// Scopes the store to one that exposes child state and actions.
  ///
  /// This can be useful for deriving new stores to hand to child views in an application. For
  /// example:
  ///
  /// ```swift
  /// @Reducer
  /// struct AppFeature {
  ///   @ObservableState
  ///   struct State {
  ///     var login: Login.State
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case login(Login.Action)
  ///     // ...
  ///   }
  ///   // ...
  /// }
  ///
  /// // A store that runs the entire application.
  /// let store = Store(initialState: AppFeature.State()) {
  ///   AppFeature()
  /// }
  ///
  /// // Construct a login view by scoping the store
  /// // to one that works with only login domain.
  /// LoginView(
  ///   store: store.scope(state: \.login, action: \.login)
  /// )
  /// ```
  ///
  /// Scoping in this fashion allows you to better modularize your application. In this case,
  /// `LoginView` could be extracted to a module that has no access to `AppFeature.State` or
  /// `AppFeature.Action`.
  ///
  /// - Parameters:
  ///   - state: A key path from `State` to `ChildState`.
  ///   - action: A case key path from `Action` to `ChildAction`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<ChildState, ChildAction>(
    state: KeyPath<State, ChildState>,
    action: CaseKeyPath<Action, ChildAction>
  ) -> Store<ChildState, ChildAction> {
    self.scope(
      id: self.id(state: state, action: action),
      state: ToState(state),
      action: { action($0) },
      isInvalid: nil
    )
  }

  @available(
    *, deprecated,
    message:
      "Pass 'state' a key path to child state and 'action' a case key path to child action, instead. For more information see the following migration guide: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Store-scoping-with-key-paths"
  )
  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (_ state: State) -> ChildState,
    action fromChildAction: @escaping (_ childAction: ChildAction) -> Action
  ) -> Store<ChildState, ChildAction> {
    self.scope(
      id: nil,
      state: ToState(toChildState),
      action: fromChildAction,
      isInvalid: nil
    )
  }

  @_spi(Internals)
  public var currentState: State {
    threadCheck(status: .state)
    return self.toState(self.rootStore.state)
  }

  @_spi(Internals)
  public
    func scope<ChildState, ChildAction>(
      id: ScopeID<State, Action>?,
      state: ToState<State, ChildState>,
      action fromChildAction: @escaping (ChildAction) -> Action,
      isInvalid: ((State) -> Bool)?
    ) -> Store<ChildState, ChildAction>
  {
    threadCheck(status: .scope)

    if self.canCacheChildren,
      let id = id,
      let childStore = self.children[id] as? Store<ChildState, ChildAction>
    {
      return childStore
    }
    let childStore = Store<ChildState, ChildAction>(
      rootStore: self.rootStore,
      toState: self.toState.appending(state.base),
      fromAction: { [fromAction] in fromAction(fromChildAction($0)) }
    )
    childStore._isInvalidated =
      id == nil || !self.canCacheChildren
      ? {
        isInvalid?(self.currentState) == true || self._isInvalidated()
      }
      : { [weak self] in
        guard let self else { return true }
        return isInvalid?(self.currentState) == true || self._isInvalidated()
      }
    childStore.canCacheChildren = self.canCacheChildren && id != nil
    if let id = id, self.canCacheChildren {
      self.children[id] = childStore
    }
    return childStore
  }

  @_spi(Internals)
  public func send(
    _ action: Action,
    originatingFrom originatingAction: Action?
  ) -> Task<Void, Never>? {
    #if DEBUG
      if BindingLocal.isActive && self._isInvalidated() {
        return .none
      }
    #endif
    return self.rootStore.send(self.fromAction(action))
  }

  private init(
    rootStore: RootStore,
    toState: PartialToState<State>,
    fromAction: @escaping (Action) -> Any
  ) {
    defer { Logger.shared.log("\(storeTypeName(of: self)).init") }
    self.rootStore = rootStore
    self.toState = toState
    self.fromAction = fromAction

    #if canImport(Perception)
      func subscribeToDidSet<T: ObservableState>(_ type: T.Type) -> AnyCancellable {
        let toState = toState as! PartialToState<T>
        return rootStore.didSet
          .compactMap { [weak rootStore] in
            rootStore.map { toState($0.state) }?._$id
          }
          .removeDuplicates()
          .dropFirst()
          .sink { [weak self] _ in
            guard let self else { return }
            self._$observationRegistrar.withMutation(of: self, keyPath: \.currentState) {}
          }
      }

      if let stateType = State.self as? ObservableState.Type {
        self.parentCancellable = subscribeToDidSet(stateType)
      }
    #endif
  }

  convenience init<R: Reducer>(
    initialState: R.State,
    reducer: R
  )
  where
    R.State == State,
    R.Action == Action
  {
    self.init(
      rootStore: RootStore(initialState: initialState, reducer: reducer),
      toState: .keyPath(\State.self),
      fromAction: { $0 }
    )
  }

  /// A publisher that emits when state changes.
  ///
  /// This publisher supports dynamic member lookup so that you can pluck out a specific field in
  /// the state:
  ///
  /// ```swift
  /// store.publisher.alert
  ///   .sink { ... }
  /// ```
  public var publisher: StorePublisher<State> {
    StorePublisher(
      store: self,
      upstream: self.rootStore.didSet.map { self.currentState }
    )
  }

  @_spi(Internals) public func id<ChildState, ChildAction>(
    state: KeyPath<State, ChildState>,
    action: CaseKeyPath<Action, ChildAction>
  ) -> ScopeID<State, Action> {
    ScopeID(state: state, action: action)
  }
}

@_spi(Internals) public struct ScopeID<State, Action>: Hashable {
  let state: PartialKeyPath<State>
  let action: PartialCaseKeyPath<Action>
}

extension Store: CustomDebugStringConvertible {
  public var debugDescription: String {
    storeTypeName(of: self)
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
public typealias StoreOf<R: Reducer> = Store<R.State, R.Action>

/// A publisher of store state.
@dynamicMemberLookup
public struct StorePublisher<State>: Publisher {
  public typealias Output = State
  public typealias Failure = Never

  let store: Any
  let upstream: AnyPublisher<State, Never>

  init<P: Publisher>(
    store: Any,
    upstream: P
  ) where P.Output == Output, P.Failure == Failure {
    self.store = store
    self.upstream = upstream.eraseToAnyPublisher()
  }

  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    self.upstream.subscribe(
      AnySubscriber(
        receiveSubscription: subscriber.receive(subscription:),
        receiveValue: subscriber.receive(_:),
        receiveCompletion: { [store = self.store] in
          subscriber.receive(completion: $0)
          _ = store
        }
      )
    )
  }

  /// Returns the resulting publisher of a given key path.
  public subscript<Value: Equatable>(
    dynamicMember keyPath: KeyPath<State, Value>
  ) -> StorePublisher<Value> {
    .init(store: self.store, upstream: self.upstream.map(keyPath).removeDuplicates())
  }
}

/// The type returned from ``Store/send(_:)`` that represents the lifecycle of the effect
/// started from sending an action.
///
/// You can use this value to tie the effect's lifecycle _and_ cancellation to an asynchronous
/// context, such as the `task` view modifier.
///
/// ```swift
/// .task { await store.send(.task).finish() }
/// ```
///
/// > Note: Unlike Swift's `Task` type, ``StoreTask`` automatically sets up a cancellation
/// > handler between the current async context and the task.
///
/// See ``TestStoreTask`` for the analog returned from ``TestStore``.
public struct StoreTask: Hashable, Sendable {
  internal let rawValue: Task<Void, Never>?

  internal init(rawValue: Task<Void, Never>?) {
    self.rawValue = rawValue
  }

  /// Cancels the underlying task.
  public func cancel() {
    self.rawValue?.cancel()
  }

  /// Waits for the task to finish.
  public func finish() async {
    await self.rawValue?.cancellableValue
  }

  /// A Boolean value that indicates whether the task should stop executing.
  ///
  /// After the value of this property becomes `true`, it remains `true` indefinitely. There is no
  /// way to uncancel a task.
  public var isCancelled: Bool {
    self.rawValue?.isCancelled ?? true
  }
}

private protocol _OptionalProtocol {}
extension Optional: _OptionalProtocol {}
extension PresentationState: _OptionalProtocol {}

func storeTypeName<State, Action>(of store: Store<State, Action>) -> String {
  let stateType = typeName(State.self, genericsAbbreviated: false)
  let actionType = typeName(Action.self, genericsAbbreviated: false)
  if stateType.hasSuffix(".State"),
    actionType.hasSuffix(".Action"),
    stateType.dropLast(6) == actionType.dropLast(7)
  {
    return "StoreOf<\(stateType.dropLast(6))>"
  } else if stateType.hasSuffix(".State?"),
    actionType.hasSuffix(".Action"),
    stateType.dropLast(7) == actionType.dropLast(7)
  {
    return "StoreOf<\(stateType.dropLast(7))?>"
  } else if stateType.hasPrefix("IdentifiedArray<"),
    actionType.hasPrefix("IdentifiedAction<"),
    stateType.dropFirst(16).dropLast(7) == actionType.dropFirst(17).dropLast(8)
  {
    return "IdentifiedStoreOf<\(stateType.drop(while: { $0 != "," }).dropFirst(2).dropLast(7))>"
  } else if stateType.hasPrefix("PresentationState<"),
    actionType.hasPrefix("PresentationAction<"),
    stateType.dropFirst(18).dropLast(7) == actionType.dropFirst(19).dropLast(8)
  {
    return "PresentationStoreOf<\(stateType.dropFirst(18).dropLast(7))>"
  } else if stateType.hasPrefix("StackState<"),
    actionType.hasPrefix("StackAction<"),
    stateType.dropFirst(11).dropLast(7)
      == actionType.dropFirst(12).prefix(while: { $0 != "," }).dropLast(6)
  {
    return "StackStoreOf<\(stateType.dropFirst(11).dropLast(7))>"
  } else {
    return "Store<\(stateType), \(actionType)>"
  }
}

// NB: From swift-custom-dump. Consider publicizing interface in some way to keep things in sync.
func typeName(
  _ type: Any.Type,
  qualified: Bool = true,
  genericsAbbreviated: Bool = true
) -> String {
  var name = _typeName(type, qualified: qualified)
    .replacingOccurrences(
      of: #"\(unknown context at \$[[:xdigit:]]+\)\."#,
      with: "",
      options: .regularExpression
    )
  for _ in 1...10 {  // NB: Only handle so much nesting
    let abbreviated =
      name
      .replacingOccurrences(
        of: #"\bSwift.Optional<([^><]+)>"#,
        with: "$1?",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: #"\bSwift.Array<([^><]+)>"#,
        with: "[$1]",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: #"\bSwift.Dictionary<([^,<]+), ([^><]+)>"#,
        with: "[$1: $2]",
        options: .regularExpression
      )
    if abbreviated == name { break }
    name = abbreviated
  }
  name = name.replacingOccurrences(
    of: #"\w+\.([\w.]+)"#,
    with: "$1",
    options: .regularExpression
  )
  if genericsAbbreviated {
    name = name.replacingOccurrences(
      of: #"<.+>"#,
      with: "",
      options: .regularExpression
    )
  }
  return name
}

@_spi(Internals)
public struct ToState<State, ChildState> {
  fileprivate let base: PartialToState<ChildState>
  @_spi(Internals)
  public init(_ closure: @escaping (State) -> ChildState) {
    self.base = .closure { closure($0 as! State) }
  }
  @_spi(Internals)
  public init(_ keyPath: KeyPath<State, ChildState>) {
    self.base = .keyPath(keyPath)
  }
}

private enum PartialToState<State> {
  case closure((Any) -> State)
  case keyPath(AnyKeyPath)
  case appended((Any) -> Any, AnyKeyPath)
  func callAsFunction(_ state: Any) -> State {
    switch self {
    case let .closure(closure):
      return closure(state)
    case let .keyPath(keyPath):
      return state[keyPath: keyPath] as! State
    case let .appended(closure, keyPath):
      return closure(state)[keyPath: keyPath] as! State
    }
  }
  func appending<ChildState>(_ state: PartialToState<ChildState>) -> PartialToState<ChildState> {
    switch (self, state) {
    case let (.keyPath(lhs), .keyPath(rhs)):
      return .keyPath(lhs.appending(path: rhs)!)
    case let (.closure(lhs), .keyPath(rhs)):
      return .appended(lhs, rhs)
    case let (.appended(lhsClosure, lhsKeyPath), .keyPath(rhs)):
      return .appended(lhsClosure, lhsKeyPath.appending(path: rhs)!)
    default:
      return .closure { state(self($0)) }
    }
  }
}

#if canImport(Perception)
  let _isStorePerceptionCheckingEnabled: Bool = {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      return false
    } else {
      return true
    }
  }()
#endif
