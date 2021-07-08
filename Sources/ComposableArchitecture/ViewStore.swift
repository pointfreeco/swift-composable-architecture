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
/// The ``ViewStore`` class is not thread-safe, and all interactions with it must happen on the main
/// thread. See the documentation of the ``Store`` class for more information why this decision was
/// made.
@dynamicMemberLookup
public final class ViewStore<State, Action>: ObservableObject {
  /// A publisher of state.
  public let publisher: StorePublisher<State>

  // N.B. `ViewStore` does not use a `@Published` property, so `objectWillChange`
  // won't be synthesized automatically. To work around issues on iOS 13 we explicitly declare it.
  public private(set) lazy var objectWillChange = ObservableObjectPublisher()

  private let _send: (Action) -> Void
  private let _state: CurrentValueSubject<State, Never>
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
    self._send = store.send
    self._state = CurrentValueSubject(store.state.value)

    self.publisher = StorePublisher(self._state)
    self.viewCancellable = store.state
      .removeDuplicates(by: isDuplicate)
      .sink { [weak self] in
        guard let self = self else { return }
        self.objectWillChange.send()
        self._state.send($0)
      }
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
    Binding(
      get: { get(self._state.value) },
      set: { newLocalState, transaction in
        if transaction.animation != nil {
          withTransaction(transaction) {
            self.send(localStateToViewAction(newLocalState))
          }
        } else {
          self.send(localStateToViewAction(newLocalState))
        }
      }
    )
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
