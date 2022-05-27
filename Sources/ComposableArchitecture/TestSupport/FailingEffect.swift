import XCTestDynamicOverlay

extension Effect {
  /// An effect that causes a test to fail if it runs.
  ///
  /// This effect can provide an additional layer of certainty that a tested code path does not
  /// execute a particular effect.
  ///
  /// For example, let's say we have a very simple counter application, where a user can increment
  /// and decrement a number. The state and actions are simple enough:
  ///
  /// ```swift
  /// struct CounterState: Equatable {
  ///   var count = 0
  /// }
  ///
  /// enum CounterAction: Equatable {
  ///   case decrementButtonTapped
  ///   case incrementButtonTapped
  /// }
  /// ```
  ///
  /// Let's throw in a side effect. If the user attempts to decrement the counter below zero, the
  /// application should refuse and play an alert sound instead.
  ///
  /// We can model playing a sound in the environment with an effect:
  ///
  /// ```swift
  /// struct CounterEnvironment {
  ///   let playAlertSound: () -> Effect<Never, Never>
  /// }
  /// ```
  ///
  /// Now that we've defined the domain, we can describe the logic in a reducer:
  ///
  /// ```swift
  /// let counterReducer = Reducer<
  ///   CounterState, CounterAction, CounterEnvironment
  /// > { state, action, environment in
  ///   switch action {
  ///   case .decrementButtonTapped:
  ///     if state > 0 {
  ///       state.count -= 0
  ///       return .none
  ///     } else {
  ///       return environment.playAlertSound()
  ///         .fireAndForget()
  ///     }
  ///
  ///   case .incrementButtonTapped:
  ///     state.count += 1
  ///     return .none
  ///   }
  /// }
  /// ```
  ///
  /// Let's say we want to write a test for the increment path. We can see in the reducer that it
  /// should never play an alert, so we can configure the environment with an effect that will
  /// fail if it ever executes:
  ///
  /// ```swift
  /// func testIncrement() {
  ///   let store = TestStore(
  ///     initialState: CounterState(count: 0)
  ///     reducer: counterReducer,
  ///     environment: CounterEnvironment(
  ///       playSound: .failing("playSound")
  ///     )
  ///   )
  ///
  ///   store.send(.increment) {
  ///     $0.count = 1
  ///   }
  /// }
  /// ```
  ///
  /// By using a `.failing` effect in our environment we have strengthened the assertion and made
  /// the test easier to understand at the same time. We can see, without consulting the reducer
  /// itself, that this particular action should not access this effect.
  ///
  /// - Parameter prefix: A string that identifies this scheduler and will prefix all failure
  ///   messages.
  /// - Returns: An effect that causes a test to fail if it runs.
  public static func failing(_ prefix: String) -> Self {
    .fireAndForget {
      XCTFail("\(prefix.isEmpty ? "" : "\(prefix) - ")A failing effect ran.")
    }
  }
}
