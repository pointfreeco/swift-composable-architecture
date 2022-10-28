#if compiler(>=5.7)
  /// A protocol that describes how to evolve the current state of an application to the next state,
  /// given an action, and describes what ``EffectTask``s should be executed later by the store, if
  /// any.
  ///
  /// Conform types to this protocol to represent the domain, logic and behavior for your feature.
  /// The domain is specified by the "state" and "actions", which can be nested types inside the
  /// conformance:
  ///
  /// ```swift
  /// struct Feature: ReducerProtocol {
  ///   struct State {
  ///     var count = 0
  ///   }
  ///   enum Action {
  ///     case decrementButtonTapped
  ///     case incrementButtonTapped
  ///   }
  ///
  ///   // ...
  /// }
  /// ```
  ///
  /// The logic of your feature is implemented by mutating the feature's current state when an action
  /// comes into the system. This is most easily done by implementing the
  /// ``ReducerProtocol/reduce(into:action:)-8yinq`` method of the protocol.
  ///
  /// ```swift
  /// struct Feature: ReducerProtocol {
  ///   // ...
  ///
  ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
  ///     switch action {
  ///     case .decrementButtonTapped:
  ///       state.count -= 1
  ///       return .none
  ///
  ///     case .incrementButtonTapped:
  ///       state.count += 1
  ///       return .none
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// The `reduce` method's first responsibility is to mutate the feature's current state given an
  /// action. It's second responsibility is to return effects that will be executed asynchronously
  /// and feed their data back into the system. Currently `Feature` does not need to run any effects,
  /// and so ``EffectPublisher/none`` is returned.
  ///
  /// If the feature does need to do effectful work, then more would need to be done. For example,
  /// suppose the feature has the ability to start and stop a timer, and with each tick of the timer
  /// the `count` was incremented. That could be done like so:
  ///
  /// ```swift
  /// struct Feature: ReducerProtocol {
  ///   struct State {
  ///     var count = 0
  ///   }
  ///   enum Action {
  ///     case decrementButtonTapped
  ///     case incrementButtonTapped
  ///     case startTimerButtonTapped
  ///     case stopTimerButtonTapped
  ///     case timerTick
  ///   }
  ///   enum TimerID {}
  ///
  ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
  ///     switch action {
  ///     case .decrementButtonTapped:
  ///       state.count -= 1
  ///       return .none
  ///
  ///     case .incrementButtonTapped:
  ///       state.count += 1
  ///       return .none
  ///
  ///     case startTimerButtonTapped:
  ///       return .run { send in
  ///         while true {
  ///           try await Task.sleep(for: .seconds(1))
  ///           await send(.timerTick)
  ///         }
  ///       }
  ///       .cancellable(TimerID.self)
  ///
  ///     case stopTimerButtonTapped:
  ///       return .cancel(TimerID.self)
  ///
  ///     case timerTick:
  ///       state.count += 1
  ///       return .none
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// > Note: This sample emulates a timer by performing an infinite loop with a `Task.sleep`
  /// inside. This is simple to do, but is also inaccurate since small imprecisions can accumulate.
  /// It would be better to inject a clock into the feature so that you could use its `timer`
  /// method. Read the <doc:DependencyManagement> and <doc:Testing> articles for more
  /// information.
  ///
  /// That is the basics of implementing a feature as a conformance to ``ReducerProtocol``. There are
  /// actually two ways to define a reducer:
  ///
  ///   1. You can either implement the ``reduce(into:action:)-8yinq`` method, as shown above, which
  ///   is given direct mutable access to application ``State`` whenever an ``Action`` is fed into
  ///   the system, and returns an ``EffectTask`` that can communicate with the outside world and
  ///   feed additional ``Action``s back into the system.
  ///
  ///   2. Or you can implement the ``body-swift.property-7foai`` property, which combines one or
  ///   more reducers together.
  ///
  /// At most one of these requirements should be implemented. If a conformance implements both
  /// requirements, only ``reduce(into:action:)-8yinq`` will be called by the ``Store``. If your
  /// reducer assembles a body from other reducers _and_ has additional business logic it needs to
  /// layer onto the feature, introduce this logic into the body instead, either with ``Reduce``:
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   Reduce { state, action in
  ///     // extra logic
  ///   }
  ///   Activity()
  ///   Profile()
  ///   Settings()
  /// }
  /// ```
  ///
  /// …or moving the extra logic to a method that is wrapped in ``Reduce``:
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   Reduce(self.core)
  ///   Activity()
  ///   Profile()
  ///   Settings()
  /// }
  ///
  /// func core(state: inout State, action: Action) -> EffectTask<Action> {
  ///   // extra logic
  /// }
  /// ```
  ///
  /// If you are implementing a custom reducer operator that transforms an existing reducer,
  /// _always_ invoke the ``reduce(into:action:)-8yinq`` method, never the
  /// ``body-swift.property-7foai``. For example, this operator that logs all actions sent to the
  /// reducer:
  ///
  /// ```swift
  /// extension ReducerProtocol {
  ///   func logActions() -> some ReducerProtocol<State, Action> {
  ///     Reduce { state, action in
  ///       print("Received action: \(action)")
  ///       return self.reduce(into: &state, action: action)
  ///     }
  ///   }
  /// }
  /// ```
  ///
  public protocol ReducerProtocol<State,Action> {
    /// A type that holds the current state of the reducer.
    associatedtype State

    /// A type that holds all possible actions that cause the ``State`` of the reducer to change
    /// and/or kick off a side ``EffectTask`` that can communicate with the outside world.
    associatedtype Action

    // NB: For Xcode to favor autocompleting `var body: Body` over `var body: Never` we must use a
    //     type alias.
    associatedtype _Body

    /// A type representing the body of this reducer.
    ///
    /// When you create a custom reducer by implementing the ``body-swift.property-7foai``, Swift
    /// infers this type from the value returned.
    ///
    /// If you create a custom reducer by implementing the ``reduce(into:action:)-8yinq``, Swift
    /// infers this type to be `Never`.
    typealias Body = _Body

    /// Evolves the current state of the reducer to the next state.
    ///
    /// Implement this requirement for "primitive" reducers, or reducers that work on leaf node
    /// features. To define a reducer by combining the logic of other reducers together, implement
    /// the ``body-swift.property-97ymy`` requirement instead.
    ///
    /// - Parameters:
    ///   - state: The current state of the reducer.
    ///   - action: An action that can cause the state of the reducer to change, and/or kick off a
    ///     side effect that can communicate with the outside world.
    /// - Returns: An effect that can communicate with the outside world and feed actions back into
    ///   the system.
    func reduce(into state: inout State, action: Action) -> EffectTask<Action>

    /// The content and behavior of a reducer that is composed from other reducers.
    ///
    /// Implement this requirement when you want to incorporate the behavior of other reducers
    /// together.
    ///
    /// Do not invoke this property directly.
    ///
    /// > Important: if your reducer implements the ``reduce(into:action:)-8yinq`` method, it will
    /// > take precedence over this property, and only ``reduce(into:action:)-8yinq`` will be called
    /// > by the ``Store``. If your reducer assembles a body from other reducers and has additional
    /// > business logic it needs to layer into the system, introduce this logic into the body
    /// > instead, either with ``Reduce``, or with a separate, dedicated conformance.
    @ReducerBuilder<State, Action>
    var body: Body { get }
  }
#else
  /// A protocol that describes how to evolve the current state of an application to the next state,
  /// given an action, and describes what ``EffectTask``s should be executed later by the store, if
  /// any.
  ///
  /// There are two ways to define a reducer:
  ///
  ///   1. You can either implement the ``reduce(into:action:)-8yinq`` method, which is given direct
  ///      mutable access to application ``State`` whenever an ``Action`` is fed into the system,
  ///      and returns an ``EffectTask`` that can communicate with the outside world and feed
  ///      additional ``Action``s back into the system.
  ///
  ///   2. Or you can implement the ``body-swift.property-7foai`` property, which combines one or
  ///      more reducers together.
  ///
  /// At most one of these requirements should be implemented. If a conformance implements both
  /// requirements, only ``reduce(into:action:)-8yinq`` will be called by the ``Store``. If your
  /// reducer assembles a body from other reducers _and_ has additional business logic it needs to
  /// layer onto the feature, introduce this logic into the body instead, either with ``Reduce``:
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   Reduce { state, action in
  ///     // extra logic
  ///   }
  ///   Activity()
  ///   Profile()
  ///   Settings()
  /// }
  /// ```
  ///
  /// ...or with a separate, dedicated conformance:
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   Core()
  ///   Activity()
  ///   Profile()
  ///   Settings()
  /// }
  /// struct Core: ReducerProtocol<State, Action> {
  ///   // extra logic
  /// }
  /// ```
  ///
  /// If you are implementing a custom reducer operator that transforms an existing reducer,
  /// _always_ invoke the ``reduce(into:action:)-8yinq`` method, never the
  /// ``body-swift.property-7foai``. For example, this operator that logs all actions sent to the
  /// reducer:
  ///
  /// ```swift
  /// extension ReducerProtocol {
  ///   func logActions() -> some ReducerProtocol<State, Action> {
  ///     Reduce { state, action in
  ///       print("Received action: \(action)")
  ///       return self.reduce(into: &state, action: action)
  ///     }
  ///   }
  /// }
  /// ```
  public protocol ReducerProtocol {
    /// A type that holds the current state of the reducer.
    associatedtype State

    /// A type that holds all possible actions that cause the ``State`` of the reducer to change
    /// and/or kick off a side ``EffectTask`` that can communicate with the outside world.
    associatedtype Action

    // NB: For Xcode to favor autocompleting `var body: Body` over `var body: Never` we must use a
    //     type alias.
    associatedtype _Body

    /// A type representing the body of this reducer.
    ///
    /// When you create a custom reducer by implementing the ``body-swift.property-7foai``, Swift
    /// infers this type from the value returned.
    ///
    /// If you create a custom reducer by implementing the ``reduce(into:action:)-8yinq``, Swift
    /// infers this type to be `Never`.
    typealias Body = _Body

    /// Evolves the current state of an reducer to the next state.
    ///
    /// Implement this requirement for "primitive" reducers, or reducers that work on leaf node
    /// features. To define a reducer by combining the logic of other reducers together, implement
    /// the ``body-swift.property-7foai`` requirement instead.
    ///
    /// - Parameters:
    ///   - state: The current state of the reducer.
    ///   - action: An action that can cause the state of the reducer to change, and/or kick off
    ///     a side effect that can communicate with the outside world.
    /// - Returns: An effect that can communicate with the outside world and feed actions back into
    ///   the system.
    func reduce(into state: inout State, action: Action) -> EffectTask<Action>

    /// The content and behavior of a reducer that is composed from other reducers.
    ///
    /// Implement this requirement when you want to incorporate the behavior of other reducers
    /// together.
    ///
    /// Do not invoke this property directly.
    ///
    /// > Important: if your reducer implements the ``reduce(into:action:)-8yinq`` method, it will
    /// > take precedence over this property, and only ``reduce(into:action:)-8yinq`` will be called
    /// > by the ``Store``. If your reducer assembles a body from other reducers and has additional
    /// > business logic it needs to layer into the system, introduce this logic into the body
    /// > instead, either with ``Reduce``, or with a separate, dedicated conformance.
    @ReducerBuilder<State, Action>
    var body: Body { get }
  }
#endif

extension ReducerProtocol where Body == Never {
  /// A non-existent body.
  ///
  /// > Warning: Do not invoke this property directly. It will trigger a fatal error at runtime.
  @_transparent
  public var body: Body {
    fatalError(
      """
      '\(Self.self)' has no body. …

      Do not access a reducer's 'body' property directly, as it may not exist. To run a reducer, \
      call 'Reducer.reduce(into:action:)', instead.
      """
    )
  }
}

extension ReducerProtocol where Body: ReducerProtocol, Body.State == State, Body.Action == Action {
  /// Invokes the ``Body-40qdd``'s implementation of ``reduce(into:action:)-8yinq``.
  @inlinable
  public func reduce(
    into state: inout Body.State, action: Body.Action
  ) -> EffectTask<Body.Action> {
    self.body.reduce(into: &state, action: action)
  }
}

// NB: This is available only in Swift 5.7.1 due to the following bug:
//     https://github.com/apple/swift/issues/60550
#if swift(>=5.7.1)
  /// A convenience for constraining a ``ReducerProtocol`` conformance. Available only in Swift
  /// 5.7.1.
  ///
  /// This allows you to specify the `body` of a ``ReducerProtocol`` conformance like so:
  ///
  /// ```swift
  /// var body: some ReducerProtocolOf<Self> {
  ///   // ...
  /// }
  /// ```
  ///
  /// …instead of the more verbose:
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   // ...
  /// }
  /// ```
  public typealias ReducerProtocolOf<R: ReducerProtocol> = ReducerProtocol<R.State, R.Action>
#endif
