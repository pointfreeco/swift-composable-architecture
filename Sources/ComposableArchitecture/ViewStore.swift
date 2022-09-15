import Combine
import SwiftUI

/// A `ViewStore` is an object that can observe state changes and send actions. They are most
/// commonly used in views, such as SwiftUI views, UIView or UIViewController, but they can be used
/// anywhere it makes sense to observe state or send actions.
///
/// In SwiftUI applications, a `ViewStore` is accessed most commonly using the ``WithViewStore``
/// view. It can be initialized with a store and a closure that is handed a view store and returns a
/// view:
///
/// ```swift
/// var body: some View {
///   WithViewStore(self.store, observe: { $0 }) { viewStore in
///     VStack {
///       Text("Current count: \(viewStore.count)")
///       Button("Increment") { viewStore.send(.incrementButtonTapped) }
///     }
///   }
/// }
/// ```
///
/// View stores can also be observed directly by views, scenes, commands, and other contexts that
/// support the `@ObservedObject` property wrapper:
///
/// ```swift
/// @ObservedObject var viewStore: ViewStore<State, Action>
/// ```
///
/// > Tip: If you experience compile-time issues with views that use ``WithViewStore``, try
/// > observing the view store directly using the `@ObservedObject` property wrapper, instead, which
/// > is easier on the compiler.
///
/// In UIKit applications a `ViewStore` can be created from a ``Store`` and then subscribed to for
/// state updates:
///
/// ```swift
/// let store: Store<State, Action>
/// let viewStore: ViewStore<State, Action>
/// private var cancellables: Set<AnyCancellable> = []
///
/// init(store: Store<State, Action>) {
///   self.store = store
///   self.viewStore = ViewStore(store)
/// }
///
/// func viewDidLoad() {
///   super.viewDidLoad()
///
///   self.viewStore.publisher.count
///     .sink { [weak self] in self?.countLabel.text = $0 }
///     .store(in: &self.cancellables)
/// }
///
/// @objc func incrementButtonTapped() {
///   self.viewStore.send(.incrementButtonTapped)
/// }
/// ```
///
/// > Important: The `ViewStore` class is not thread-safe, and all interactions with it (and the
/// > store it was derived from) must happen on the same thread. Further, for SwiftUI applications,
/// > all interactions must happen on the _main_ thread. See the documentation of the ``Store``
/// > class for more information as to why this decision was made.
@dynamicMemberLookup
public final class ViewStore<State, Action>: ObservableObject {
  // N.B. `ViewStore` does not use a `@Published` property, so `objectWillChange`
  // won't be synthesized automatically. To work around issues on iOS 13 we explicitly declare it.
  public private(set) lazy var objectWillChange = ObservableObjectPublisher()

  private let _send: (Action) -> Task<Void, Never>?
  fileprivate let _state: CurrentValueRelay<State>
  private var viewCancellable: AnyCancellable?

  /// Initializes a view store from a store.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed.
  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool
  ) {
    self._send = { store.send($0) }
    self._state = CurrentValueRelay(store.state.value)
    self.viewCancellable = store.state
      .removeDuplicates(by: isDuplicate)
      .sink { [weak objectWillChange = self.objectWillChange, weak _state = self._state] in
        guard let objectWillChange = objectWillChange, let _state = _state else { return }
        objectWillChange.send()
        _state.value = $0
      }
  }

  internal init(_ viewStore: ViewStore<State, Action>) {
    self._send = viewStore._send
    self._state = viewStore._state
    self.objectWillChange = viewStore.objectWillChange
    self.viewCancellable = viewStore.viewCancellable
  }

  /// A publisher that emits when state changes.
  ///
  /// This publisher supports dynamic member lookup so that you can pluck out a specific field in
  /// the state:
  ///
  /// ```swift
  /// viewStore.publisher.alert
  ///   .sink { ... }
  /// ```
  ///
  /// When the emission happens the ``ViewStore``'s state has been updated, and so the following
  /// precondition will pass:
  ///
  /// ```swift
  /// viewStore.publisher
  ///   .sink { precondition($0 == viewStore.state) }
  /// ```
  ///
  /// This means you can either use the value passed to the closure or you can reach into
  /// `viewStore.state` directly.
  ///
  /// - Note: Due to a bug in Combine (or feature?), the order you `.sink` on a publisher has no
  ///   bearing on the order the `.sink` closures are called. This means the work performed inside
  ///   `viewStore.publisher.sink` closures should be completely independent of each other. Later
  ///   closures cannot assume that earlier ones have already run.
  public var publisher: StorePublisher<State> {
    StorePublisher(viewStore: self)
  }

  /// The current state.
  public var state: State {
    self._state.value
  }

  /// Returns the resulting value of a given key path.
  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self._state.value[keyPath: keyPath]
  }

  /// Sends an action to the store.
  ///
  /// This method returns a ``ViewStoreTask``, which represents the lifecycle of the effect started
  /// from sending an action. You can use this value to tie the effect's lifecycle _and_
  /// cancellation to an asynchronous context, such as SwiftUI's `task` view modifier:
  ///
  /// ```swift
  /// .task { await viewStore.send(.task).finish() }
  /// ```
  ///
  /// > Important: ``ViewStore`` is not thread safe and you should only send actions to it from the
  /// > main thread. If you want to send actions on background threads due to the fact that the
  /// > reducer is performing computationally expensive work, then a better way to handle this is to
  /// > wrap that work in an ``Effect`` that is performed on a background thread so that the result
  /// > can be fed back into the store.
  ///
  /// - Parameter action: An action.
  /// - Returns: A ``ViewStoreTask`` that represents the lifecycle of the effect executed when
  ///   sending the action.
  @discardableResult
  public func send(_ action: Action) -> ViewStoreTask {
    .init(rawValue: self._send(action))
  }

  /// Sends an action to the store with a given animation.
  ///
  /// See ``ViewStore/send(_:)`` for more info.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - animation: An animation.
  @discardableResult
  public func send(_ action: Action, animation: Animation?) -> ViewStoreTask {
    withAnimation(animation) {
      self.send(action)
    }
  }

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
  ///   case receivedResponse(TaskResult<String>)
  /// }
  ///
  /// struct Environment {
  ///   var fetch: () async throws -> String
  /// }
  ///
  /// let reducer = Reducer<State, Action, Environment> { state, action, environment in
  ///   switch action {
  ///   case .pulledToRefresh:
  ///     state.isLoading = true
  ///     return .task {
  ///       await .receivedResponse(TaskResult { try await environment.fetch() })
  ///     }
  ///
  ///   case let .receivedResponse(result):
  ///     state.isLoading = false
  ///     state.response = try? result.value
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
  ///     WithViewStore(self.store, observe: { $0 }) { viewStore in
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
  /// - Parameters:
  ///   - action: An action.
  ///   - predicate: A predicate on `State` that determines for how long this method should suspend.
  @MainActor
  public func send(_ action: Action, while predicate: @escaping (State) -> Bool) async {
    let task = self.send(action)
    await withTaskCancellationHandler {
      await self.yield(while: predicate)
    } onCancel: {
      task.rawValue?.cancel()
    }
  }

  /// Sends an action into the store and then suspends while a piece of state is `true`.
  ///
  /// See the documentation of ``send(_:while:)`` for more information.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - animation: The animation to perform when the action is sent.
  ///   - predicate: A predicate on `State` that determines for how long this method should suspend.
  @MainActor
  public func send(
    _ action: Action,
    animation: Animation?,
    while predicate: @escaping (State) -> Bool
  ) async {
    let task = withAnimation(animation) { self.send(action) }
    await withTaskCancellationHandler {
      await self.yield(while: predicate)
    } onCancel: {
      task.rawValue?.cancel()
    }
  }

  /// Suspends the current task while a predicate on state is `true`.
  ///
  /// If you want to suspend at the same time you send an action to the view store, use
  /// ``send(_:while:)``.
  ///
  /// - Parameter predicate: A predicate on `State` that determines for how long this method should
  ///   suspend.
  @MainActor
  public func yield(while predicate: @escaping (State) -> Bool) async {
    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      _ = await self.publisher
        .values
        .first(where: { !predicate($0) })
    } else {
      let cancellable = Box<AnyCancellable?>(wrappedValue: nil)
      try? await withTaskCancellationHandler {
        try Task.checkCancellation()
        try await withUnsafeThrowingContinuation {
          (continuation: UnsafeContinuation<Void, Error>) in
          guard !Task.isCancelled else {
            continuation.resume(throwing: CancellationError())
            return
          }
          cancellable.wrappedValue = self.publisher
            .filter { !predicate($0) }
            .prefix(1)
            .sink { _ in
              continuation.resume()
              _ = cancellable
            }
        }
      } onCancel: {
        cancellable.wrappedValue?.cancel()
      }
    }
  }
  /// Derives a binding from the store that prevents direct writes to state and instead sends
  /// actions to the store.
  ///
  /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
  /// since the ``Store`` does not allow directly writing its state; it only allows reading state
  /// and sending actions.
  ///
  /// For example, a text field binding can be created like this:
  ///
  /// ```swift
  /// struct State { var name = "" }
  /// enum Action { case nameChanged(String) }
  ///
  /// TextField(
  ///   "Enter name",
  ///   text: viewStore.binding(
  ///     get: { $0.name },
  ///     send: { Action.nameChanged($0) }
  ///   )
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - get: A function to get the state for the binding from the view store's full state.
  ///   - valueToAction: A function that transforms the binding's value into an action that can be
  ///     sent to the store.
  /// - Returns: A binding.
  public func binding<Value>(
    get: @escaping (State) -> Value,
    send valueToAction: @escaping (Value) -> Action
  ) -> Binding<Value> {
    ObservedObject(wrappedValue: self)
      .projectedValue[get: .init(rawValue: get), send: .init(rawValue: valueToAction)]
  }

  /// Derives a binding from the store that prevents direct writes to state and instead sends
  /// actions to the store.
  ///
  /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
  /// since the ``Store`` does not allow directly writing its state; it only allows reading state
  /// and sending actions.
  ///
  /// For example, an alert binding can be dealt with like this:
  ///
  /// ```swift
  /// struct State { var alert: String? }
  /// enum Action { case alertDismissed }
  ///
  /// .alert(
  ///   item: self.store.binding(
  ///     get: { $0.alert },
  ///     send: .alertDismissed
  ///   )
  /// ) { alert in Alert(title: Text(alert.message)) }
  /// ```
  ///
  /// - Parameters:
  ///   - get: A function to get the state for the binding from the view store's full state.
  ///   - action: The action to send when the binding is written to.
  /// - Returns: A binding.
  public func binding<Value>(
    get: @escaping (State) -> Value,
    send action: Action
  ) -> Binding<Value> {
    self.binding(get: get, send: { _ in action })
  }

  /// Derives a binding from the store that prevents direct writes to state and instead sends
  /// actions to the store.
  ///
  /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
  /// since the ``Store`` does not allow directly writing its state; it only allows reading state
  /// and sending actions.
  ///
  /// For example, a text field binding can be created like this:
  ///
  /// ```swift
  /// typealias State = String
  /// enum Action { case nameChanged(String) }
  ///
  /// TextField(
  ///   "Enter name",
  ///   text: viewStore.binding(
  ///     send: { Action.nameChanged($0) }
  ///   )
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - valueToAction: A function that transforms the binding's value into an action that can be
  ///     sent to the store.
  /// - Returns: A binding.
  public func binding(
    send valueToAction: @escaping (State) -> Action
  ) -> Binding<State> {
    self.binding(get: { $0 }, send: valueToAction)
  }

  /// Derives a binding from the store that prevents direct writes to state and instead sends
  /// actions to the store.
  ///
  /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
  /// since the ``Store`` does not allow directly writing its state; it only allows reading state
  /// and sending actions.
  ///
  /// For example, an alert binding can be dealt with like this:
  ///
  /// ```swift
  /// typealias State = String
  /// enum Action { case alertDismissed }
  ///
  /// .alert(
  ///   item: viewStore.binding(
  ///     send: .alertDismissed
  ///   )
  /// ) { title in Alert(title: Text(title)) }
  /// ```
  ///
  /// - Parameters:
  ///   - action: The action to send when the binding is written to.
  /// - Returns: A binding.
  public func binding(send action: Action) -> Binding<State> {
    self.binding(send: { _ in action })
  }

  private subscript<Value>(
    get state: HashableWrapper<(State) -> Value>,
    send action: HashableWrapper<(Value) -> Action>
  ) -> Value {
    get { state.rawValue(self.state) }
    set { self.send(action.rawValue(newValue)) }
  }
}

extension ViewStore where State: Equatable {
  public convenience init(_ store: Store<State, Action>) {
    self.init(store, removeDuplicates: ==)
  }
}

extension ViewStore where State == Void {
  public convenience init(_ store: Store<Void, Action>) {
    self.init(store, removeDuplicates: ==)
  }
}

/// The type returned from ``ViewStore/send(_:)`` that represents the lifecycle of the effect
/// started from sending an action.
///
/// You can use this value to tie the effect's lifecycle _and_ cancellation to an asynchronous
/// context, such as the `task` view modifier.
///
/// ```swift
/// .task { await viewStore.send(.task).finish() }
/// ```
///
/// > Note: Unlike `Task`, ``ViewStoreTask`` automatically sets up a cancellation handler between
/// > the current async context and the task.
///
/// See ``TestStoreTask`` for the analog provided to ``TestStore``.
public struct ViewStoreTask: Hashable, Sendable {
  fileprivate let rawValue: Task<Void, Never>?

  /// Cancels the underlying task and waits for it to finish.
  public func cancel() async {
    self.rawValue?.cancel()
    await self.finish()
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

/// A publisher of store state.
@dynamicMemberLookup
public struct StorePublisher<State>: Publisher {
  public typealias Output = State
  public typealias Failure = Never

  public let upstream: AnyPublisher<State, Never>
  public let viewStore: Any

  fileprivate init<Action>(viewStore: ViewStore<State, Action>) {
    self.viewStore = viewStore
    self.upstream = viewStore._state.eraseToAnyPublisher()
  }

  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    self.upstream.subscribe(
      AnySubscriber(
        receiveSubscription: subscriber.receive(subscription:),
        receiveValue: subscriber.receive(_:),
        receiveCompletion: { [viewStore = self.viewStore] in
          subscriber.receive(completion: $0)
          _ = viewStore
        }
      )
    )
  }

  private init<P: Publisher>(
    upstream: P,
    viewStore: Any
  ) where P.Output == Output, P.Failure == Failure {
    self.upstream = upstream.eraseToAnyPublisher()
    self.viewStore = viewStore
  }

  /// Returns the resulting publisher of a given key path.
  public subscript<Value: Equatable>(
    dynamicMember keyPath: KeyPath<State, Value>
  ) -> StorePublisher<Value> {
    .init(upstream: self.upstream.map(keyPath).removeDuplicates(), viewStore: self.viewStore)
  }
}

private struct HashableWrapper<Value>: Hashable {
  let rawValue: Value
  static func == (lhs: Self, rhs: Self) -> Bool { false }
  func hash(into hasher: inout Hasher) {}
}
