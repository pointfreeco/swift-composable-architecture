import Combine

extension Store {
  /// Subscribes to updates when a store containing optional state goes from `nil` to non-`nil` or
  /// non-`nil` to `nil`.
  ///
  /// This is useful for handling navigation in UIKit. The state for a screen that you want to
  /// navigate to can be held as an optional value in the parent, and when that value switches
  /// from `nil` to non-`nil` you want to trigger a navigation and hand the detail view a `Store`
  /// whose domain has been scoped to just that feature:
  ///
  ///     class MasterViewController: UIViewController {
  ///       let store: Store<MasterState, MasterAction>
  ///       var cancellables: Set<AnyCancellable> = []
  ///       ...
  ///       func viewDidLoad() {
  ///         ...
  ///         self.store
  ///           .scope(state: \.optionalDetail, action: MasterAction.detail)
  ///           .ifLet(
  ///             then: { [weak self] detailStore in
  ///               self?.navigationController?.pushViewController(
  ///                 DetailViewController(store: detailStore),
  ///                 animated: true
  ///               )
  ///             },
  ///             else: { [weak self] in
  ///               guard let self = self else { return }
  ///               self.navigationController?.popToViewController(self, animated: true)
  ///             }
  ///           )
  ///           .store(in: &self.cancellables)
  ///       }
  ///     }
  ///
  /// - Parameters:
  ///   - unwrap: A function that is called with a store of non-optional state whenever the store's
  ///     optional state goes from `nil` to non-`nil`.
  ///   - else: A function that is called whenever the store's optional state goes from non-`nil` to
  ///     `nil`.
  /// - Returns: A cancellable associated with the underlying subscription.
  public func ifLet<Wrapped>(
    then unwrap: @escaping (Store<Wrapped, Action>) -> Void,
    else: @escaping () -> Void
  ) -> Cancellable where State == Wrapped? {
    let elseCancellable =
      self
      .publisherScope(
        state: { state in
          state
            .removeDuplicates(by: { ($0 != nil) == ($1 != nil) })
        }
      )
      .sink { store in
        if store.state.value == nil { `else`() }
      }

    let unwrapCancellable =
      self
      .publisherScope(
        state: { state in
          state
            .removeDuplicates(by: { ($0 != nil) == ($1 != nil) })
            .compactMap { $0 }
        }
      )
      .sink(receiveValue: unwrap)

    return AnyCancellable {
      elseCancellable.cancel()
      unwrapCancellable.cancel()
    }
  }

  /// An overload of `ifLet(then:else:)` for the times that you do not want to handle the `else`
  /// case.
  ///
  /// - Parameter unwrap: A function that is called with a store of non-optional state whenever the
  ///   store's optional state goes from `nil` to non-`nil`.
  /// - Returns: A cancellable associated with the underlying subscription.
  public func ifLet<Wrapped>(
    then unwrap: @escaping (Store<Wrapped, Action>) -> Void
  ) -> Cancellable where State == Wrapped? {
    self.ifLet(then: unwrap, else: {})
  }

  /// Synchronous unwrapping of `LocalState`
  ///
  /// This is useful for interacting with the DataSource pattern in UIKit - where a cell/view/component is re-configured on data updates.
  ///
  /// - Parameters:
  ///   - unwrap: A function that is called synchronous if the store's optional state is non-nil
  ///   - else: A function that is called synchronous if the store's optional state is `nil`
  public func ifLet<Wrapped>(
    then unwrap: (Store<Wrapped, Action>) -> Void,
    else: () -> Void
  ) where State == Wrapped? {
    guard let unwrapped = state.value else {
      `else`()
      return
    }

    let store = self.scope(state: { _ in unwrapped }, action: { $0 })
    unwrap(store)
  }

  /// An overload of the synchronous `ifLet(then:else:)` for the times that you do not want to handle the `else`
  /// case.
  ///
  /// - Parameter unwrap: A function that is called synchronously if `State` is non-nil
  public func ifLet<Wrapped>(
    then unwrap: (Store<Wrapped, Action>) -> Void
  ) where State == Wrapped? {
    self.ifLet(then: unwrap, else: {})
  }

  /// Forced unwrapping of `LocalState`
  ///
  /// This is useful for interacting with the DataSource pattern in UIKit - where a cell/view/component is re-configured on data updates.
  /// A developer may choose to reconcile the optionality of a dictionary or `IdentifiedArray` lookup with a forced unwrapping.
  ///
  /// - Parameters:
  ///   - message: A debug message to be printed alongside the fatalError
  public func guardLet<Wrapped>(_ message: @escaping @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) -> Store<Wrapped, Action> where State == Wrapped? {
    return self.scope(
      state: { (state: State) -> Wrapped in
        guard let localState = state else {
          fatalError(message(), file: file, line: line)
        }
        return localState
      },
      action: { $0 }
    )
  }

}
