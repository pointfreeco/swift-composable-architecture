#if canImport(Combine)
  import CombineSchedulers
  import Foundation

  extension DependencyValues {
    /// The "main" queue.
    ///
    /// Introduce controllable timing to your features by using the ``Dependency`` property wrapper
    /// with a key path to this property. The wrapped value is a Combine scheduler with the time
    /// type and options of a dispatch queue. By default, `DispatchQueue.main` will be provided,
    /// with the exception of XCTest cases, in which an "unimplemented" scheduler will be provided.
    ///
    /// For example, you could introduce controllable timing to a Composable Architecture reducer
    /// that counts the number of seconds it's onscreen:
    ///
    /// ```
    /// struct TimerReducer: ReducerProtocol {
    ///   struct State {
    ///     var elapsed = 0
    ///   }
    ///
    ///   enum Action {
    ///     case task
    ///     case timerTicked
    ///   }
    ///
    ///   @Dependency(\.mainQueue) var mainQueue
    ///
    ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    ///     switch action {
    ///     case .task:
    ///       return .run { send in
    ///         for await _ in self.mainQueue.timer(interval: .seconds(1)) {
    ///           await send(.timerTicked)
    ///         }
    ///       }
    ///
    ///     case .timerTicked:
    ///       state.elapsed += 1
    ///       return .none
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// And you could test this reducer by overriding its main queue with a test scheduler:
    ///
    /// ```
    /// let mainQueue = DispatchQueue.test
    ///
    /// let store = TestStore(
    ///   initialState: TimerReducer.State()
    ///   reducer: TimerReducer()
    ///     .dependency(\.mainQueue, mainQueue.eraseToAnyScheduler())
    /// )
    ///
    /// let task = store.send(.task)
    ///
    /// mainQueue.advance(by: .seconds(1)
    /// await store.receive(.timerTicked) {
    ///   $0.elapsed = 1
    /// }
    /// mainQueue.advance(by: .seconds(1)
    /// await store.receive(.timerTicked) {
    ///   $0.elapsed = 2
    /// }
    /// await task.cancel()
    /// ```
    @available(
      iOS, deprecated: 9999.0, message: "Use '\\.continuousClock' or '\\.suspendingClock' instead."
    )
    @available(
      macOS, deprecated: 9999.0,
      message: "Use '\\.continuousClock' or '\\.suspendingClock' instead."
    )
    @available(
      tvOS,
      deprecated: 9999.0,
      message: "Use '\\.continuousClock' or '\\.suspendingClock' instead."
    )
    @available(
      watchOS,
      deprecated: 9999.0,
      message: "Use '\\.continuousClock' or '\\.suspendingClock' instead."
    )
    public var mainQueue: AnySchedulerOf<DispatchQueue> {
      get { self[MainQueueKey.self] }
      set { self[MainQueueKey.self] = newValue }
    }

    private enum MainQueueKey: DependencyKey {
      static let liveValue = AnySchedulerOf<DispatchQueue>.main
      static let testValue = AnySchedulerOf<DispatchQueue>
        .unimplemented(#"@Dependency(\.mainQueue)"#)
    }
  }
#endif
