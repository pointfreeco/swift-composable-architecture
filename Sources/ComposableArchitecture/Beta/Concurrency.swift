import Combine
import SwiftUI

#if compiler(>=5.5)
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension ViewStore {
  /// Sends an action into the store and then suspends while a piece of state is `true`.
  ///
  /// This method can be used to interact with async/await code, allowing you to suspend while work
  /// is being performed in an effect. One common example of this is using SwiftUI's `.refreshable`
  /// method, which shows a loading indicator on the screen while work is being performed.
  ///
  /// For example, suppose we wanted to load some data from the network when a pull-to-refresh
  /// gesture is performed on a list. The domain and logic for this feature can be modeled like so:
  ///
  /// ```swift
  /// struct State: Equatable {
  ///   var isLoading = false
  ///   var response: String?
  /// }
  ///
  /// enum Action {
  ///   case pulledToRefresh
  ///   case receivedResponse(String?)
  /// }
  ///
  /// struct Environment {
  ///   var fetch: () -> Effect<String?, Never>
  /// }
  ///
  /// let reducer = Reducer<State, Action, Environment> { state, action, environment in
  ///   switch action {
  ///   case .pulledToRefresh:
  ///     state.isLoading = true
  ///     return environment.fetch()
  ///       .map(Action.receivedResponse)
  ///
  ///   case let .receivedResponse(responsne):
  ///     state.isLoading = false
  ///     state.response = response
  ///     return .none
  ///   }
  /// }
  /// ```
  ///
  /// Note that we keep track of an `isLoading` boolean in our state so that we know exactly when
  /// the network response is being performed.
  ///
  /// The view can show the fact in a `List`, if it's present, and we can use the `.refreshable`
  /// view modifier to enhance the list with pull-to-refresh capabilities:
  ///
  /// ```swift
  /// struct MyView: View {
  ///   let store: Store<State, Action>
  ///
  ///   var body: some View {
  ///     WithViewStore(self.store) { viewStore in
  ///       List {
  ///         if let response = viewStore.response {
  ///           Text(response)
  ///         }
  ///       }
  ///       .refreshable {
  ///         await viewStore.send(.pulledToRefresh, while: \.isLoading)
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// Here we've used the ``send(_:while:)`` method to suspend while the `isLoading` state is
  /// `true`. Once that piece of state flips back to `false` the method will resume, signaling to
  /// `.refreshable` that the work has finished which will cause the loading indicator to disappear.
  ///
  /// **Note:** ``ViewStore`` is not thread safe and you should only send actions to it from the
  /// main thread. If you are wanting to send actions on background threads due to the fact that the
  /// reducer is performing computationally expensive work, then a better way to handle this is to
  /// wrap that work in an ``Effect`` that is performed on a background thread so that the result
  /// can be fed back into the store.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - predicate: A predicate on `State` that determines for how long this method should suspend.
  public func send(
    _ action: Action,
    while predicate: @escaping (State) -> Bool
  ) async {
    self.send(action)
    await self.suspend(while: predicate)
  }

  /// Sends an action into the store and then suspends while a piece of state is `true`.
  ///
  /// See the documentation of ``send(_:while:)`` for more information.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - animation: The animation to perform when the action is sent.
  ///   - predicate: A predicate on `State` that determines for how long this method should suspend.
  public func send(
    _ action: Action,
    animation: Animation?,
    while predicate: @escaping (State) -> Bool
  ) async {
    withAnimation(animation) { self.send(action) }
    await self.suspend(while: predicate)
  }

  /// Suspends while a predicate on state is `true`.
  ///
  /// - Parameter predicate: A predicate on `State` that determines for how long this method should
  /// suspend.
  public func suspend(while predicate: @escaping (State) -> Bool) async {
    var cancellable: Cancellable?
    try? await withTaskCancellationHandler(
      handler: { [cancellable] in cancellable?.cancel() },
      operation: {
        try Task.checkCancellation()
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
          guard !Task.isCancelled else {
            continuation.resume(throwing: CancellationError())
            return
          }
          cancellable = self.publisher
            .filter { !predicate($0) }
            .prefix(1)
            .sink { _ in
              continuation.resume()
              _ = cancellable
            }
        }
      }
    )
  }
}
#endif
