import Combine
import SwiftUI

/// A ``ViewStore`` is an object that can observe state changes and send actions. They are most
/// commonly used in views, such as SwiftUI views, UIView or UIViewController, but they can be
/// used anywhere it makes sense to observe state and send actions.
///
/// In SwiftUI applications, a ``ViewStore`` is accessed most commonly using the ``WithViewStore``
/// view. It can be initialized with a store and a closure that is handed a view store and must
/// return a view to be rendered:
///
/// ```swift
/// var body: some View {
///   WithViewStore(self.store) { viewStore in
///     VStack {
///       Text("Current count: \(viewStore.count)")
///       Button("Increment") { viewStore.send(.incrementButtonTapped) }
///     }
///   }
/// }
/// ```
///
/// In UIKit applications a ``ViewStore`` can be created from a ``Store`` and then subscribed to for
/// state updates:
///
/// ```swift
/// let store: Store<State, Action>
/// let viewStore: ViewStore<State, Action>
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
/// ### Thread safety
///
/// The ``ViewStore`` class is not thread-safe, and all interactions with it (and the store it was
/// derived from) must happen on the same thread. Further, for SwiftUI applications, all
/// interactions must happen on the _main_ thread. See the documentation of the ``Store`` class for
/// more information as to why this decision was made.
@dynamicMemberLookup
public final class ViewStore<State, Action>: ObservableObject {
  // N.B. `ViewStore` does not use a `@Published` property, so `objectWillChange`
  // won't be synthesized automatically. To work around issues on iOS 13 we explicitly declare it.
  public private(set) lazy var objectWillChange = ObservableObjectPublisher()

  private let _send: (Action) -> Void
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
      .sink { [weak self] in
        guard let self = self else { return }
        self.objectWillChange.send()
        self._state.value = $0
      }
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
  ///   `viewStore.publisher.sink` closures should be completely independent of each other.
  ///   Later closures cannot assume that earlier ones have already run.
  public var publisher: StorePublisher<State> {
    StorePublisher(viewStore: self)
  }

  /// The current state.
  public var state: State {
    self._state.value
  }

  /// Returns the resulting value of a given key path.
  public subscript<LocalState>(dynamicMember keyPath: KeyPath<State, LocalState>) -> LocalState {
    self._state.value[keyPath: keyPath]
  }

  /// Sends an action to the store.
  ///
  /// ``ViewStore`` is not thread safe and you should only send actions to it from the main thread.
  /// If you are wanting to send actions on background threads due to the fact that the reducer
  /// is performing computationally expensive work, then a better way to handle this is to wrap
  /// that work in an ``Effect`` that is performed on a background thread so that the result can
  /// be fed back into the store.
  ///
  /// - Parameter action: An action.
  public func send(_ action: Action) {
    self._send(action)
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
  ///   - get: A function to get the state for the binding from the view
  ///     store's full state.
  ///   - localStateToViewAction: A function that transforms the binding's value
  ///     into an action that can be sent to the store.
  /// - Returns: A binding.
  public func binding<LocalState>(
    get: @escaping (State) -> LocalState,
    send localStateToViewAction: @escaping (LocalState) -> Action
  ) -> Binding<LocalState> {
    ObservedObject(wrappedValue: self)
      .projectedValue[get: .init(rawValue: get), send: .init(rawValue: localStateToViewAction)]
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
  public func binding<LocalState>(
    get: @escaping (State) -> LocalState,
    send action: Action
  ) -> Binding<LocalState> {
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
  ///   - localStateToViewAction: A function that transforms the binding's value
  ///     into an action that can be sent to the store.
  /// - Returns: A binding.
  public func binding(
    send localStateToViewAction: @escaping (State) -> Action
  ) -> Binding<State> {
    self.binding(get: { $0 }, send: localStateToViewAction)
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

  private subscript<LocalState>(
    get state: HashableWrapper<(State) -> LocalState>,
    send action: HashableWrapper<(LocalState) -> Action>
  ) -> LocalState {
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

  public func receive<S>(subscriber: S)
  where S: Subscriber, Failure == S.Failure, Output == S.Input {
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

  private init<P>(
    upstream: P,
    viewStore: Any
  ) where P: Publisher, Failure == P.Failure, Output == P.Output {
    self.upstream = upstream.eraseToAnyPublisher()
    self.viewStore = viewStore
  }

  /// Returns the resulting publisher of a given key path.
  public subscript<LocalState>(
    dynamicMember keyPath: KeyPath<State, LocalState>
  ) -> StorePublisher<LocalState>
  where LocalState: Equatable {
    .init(upstream: self.upstream.map(keyPath).removeDuplicates(), viewStore: self.viewStore)
  }
}

private struct HashableWrapper<Value>: Hashable {
  let rawValue: Value
  static func == (lhs: Self, rhs: Self) -> Bool { false }
  func hash(into hasher: inout Hasher) {}
}
