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
    self
      .scope(
        state: { state in
          state
            .removeDuplicates(by: { ($0 != nil) == ($1 != nil) })
            .handleEvents(receiveOutput: { if $0 == nil { `else`() } })
            .compactMap { $0 }
        },
        action: { $0 }
      )
      .sink(receiveValue: unwrap)
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
}
