import Combine
import SwiftUI

/// A `ViewStore` is an object that can observe state changes and send actions from a SwiftUI view.
///
/// In SwiftUI applications, a `ViewStore` is accessed most commonly using the `WithViewStore` view.
/// It can be initialized with a store and a closure that is handed a view store and must return a
/// view to be rendered:
///
///     var body: some View {
///       WithViewStore(self.store) { viewStore in
///         VStack {
///           Text("Current count: \(viewStore.count)")
///           Button("Increment") { viewStore.send(.incrementButtonTapped) }
///         }
///       }
///     }
///
/// In UIKit applications a `ViewStore` can be created from a `Store` and then subscribed to for
/// state updates:
///
///     let store: Store<State, Action>
///     let viewStore: ViewStore<State, Action>
///
///     init(store: Store<State, Action>) {
///       self.store = store
///       self.viewStore = ViewStore(store)
///     }
///
///     func viewDidLoad() {
///       super.viewDidLoad()
///
///       self.viewStore.publisher.count
///         .sink { [weak self] in self?.countLabel.text = $0 }
///         .store(in: &self.cancellables)
///     }
///
///     @objc func incrementButtonTapped() {
///       self.viewStore.send(.incrementButtonTapped)
///     }
///
@dynamicMemberLookup
public final class ViewStore<State, Action>: ObservableObject {
  /// A publisher of state.
  public let publisher: StorePublisher<State>

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
    let publisher = store.$state.removeDuplicates(by: isDuplicate)
    self.publisher = StorePublisher(publisher)
    self.state = store.state
    self._send = store.send
    self.viewCancellable = publisher.sink { [weak self] in self?.state = $0 }
  }

  /// The current state.
  @Published public internal(set) var state: State

  let _send: (Action) -> Void

  /// Returns the resulting value of a given key path.
  public subscript<LocalState>(dynamicMember keyPath: KeyPath<State, LocalState>) -> LocalState {
    self.state[keyPath: keyPath]
  }

  /// Sends an action to the store.
  ///
  /// `ViewStore` is not thread safe and you should only send actions to it from the main thread.
  ///
  /// - Parameter action: An action.
  public func send(_ action: Action) {
    self._send(action)
  }

  /// Derives a binding from the store that prevents direct writes to state and instead sends
  /// actions to the store.
  ///
  /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
  /// since the `Store` does not allow directly writing its state; it only allows reading state and
  /// sending actions.
  ///
  /// For example, a text field binding can be created like this:
  ///
  ///     struct State { var name = "" }
  ///     enum Action { case nameChanged(String) }
  ///
  ///     TextField(
  ///       "Enter name",
  ///       text: viewStore.binding(
  ///         get: { $0.name },
  ///         send: { Action.nameChanged($0) }
  ///       )
  ///     )
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
      get: { get(self.state) },
      set: { newLocalState, transaction in
        withAnimation(transaction.disablesAnimations ? nil : transaction.animation) {
          self.send(localStateToViewAction(newLocalState))
        }
      })
  }

  /// Derives a binding from the store that prevents direct writes to state and instead sends
  /// actions to the store.
  ///
  /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
  /// since the `Store` does not allow directly writing its state; it only allows reading state and
  /// sending actions.
  ///
  /// For example, an alert binding can be dealt with like this:
  ///
  ///     struct State { var alert: String? }
  ///     enum Action { case alertDismissed }
  ///
  ///     .alert(
  ///       item: self.store.binding(
  ///         get: { $0.alert },
  ///         send: .alertDismissed
  ///       )
  ///     ) { alert in Alert(title: Text(alert.message)) }
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
  /// since the `Store` does not allow directly writing its state; it only allows reading state and
  /// sending actions.
  ///
  /// For example, a text field binding can be created like this:
  ///
  ///     struct State { var name = "" }
  ///     enum Action { case nameChanged(String) }
  ///
  ///     TextField(
  ///       "Enter name",
  ///       text: viewStore.binding(
  ///         send: { Action.nameChanged($0) }
  ///       )
  ///     )
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
  /// since the `Store` does not allow directly writing its state; it only allows reading state and
  /// sending actions.
  ///
  /// For example, an alert binding can be dealt with like this:
  ///
  ///     struct State { var alert: String? }
  ///     enum Action { case alertDismissed }
  ///
  ///     .alert(
  ///       item: self.store.binding(
  ///         send: .alertDismissed
  ///       )
  ///     ) { alert in Alert(title: Text(alert.message)) }
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
