import Combine

extension Store {
  /// Calls one of two closures depending on whether a store's optional state is `nil` or not, and
  /// whenever this condition changes for as long as the cancellable lives.
  ///
  /// If the store's state is non-`nil`, it will safely unwrap the value and bundle it into a new
  /// store of non-optional state that is passed to the first closure. If the store's state is
  /// `nil`, the second closure is called instead.
  ///
  /// This method is useful for handling navigation in UIKit. The state for a screen the user wants
  /// to navigate to can be held as an optional value in the parent, and when that value goes from
  /// `nil` to non-`nil`, or non-`nil` to `nil`, you can update the navigation stack accordingly:
  ///
  /// ```swift
  /// class ParentViewController: UIViewController {
  ///   let store: Store<ParentState, ParentAction>
  ///   var cancellables: Set<AnyCancellable> = []
  ///   ...
  ///   func viewDidLoad() {
  ///     ...
  ///     self.store
  ///       .scope(state: \.optionalChild, action: ParentAction.child)
  ///       .ifLet(
  ///         then: { [weak self] childStore in
  ///           self?.navigationController?.pushViewController(
  ///             ChildViewController(store: childStore),
  ///             animated: true
  ///           )
  ///         },
  ///         else: { [weak self] in
  ///           guard let self = self else { return }
  ///           self.navigationController?.popToViewController(self, animated: true)
  ///         }
  ///       )
  ///       .store(in: &self.cancellables)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - unwrap: A function that is called with a store of non-optional state when the store's
  ///     state is non-`nil`, or whenever it goes from `nil` to non-`nil`.
  ///   - else: A function that is called when the store's optional state is `nil`, or whenever it
  ///     goes from non-`nil` to `nil`.
  /// - Returns: A cancellable that maintains a subscription to updates whenever the store's state
  ///   goes from `nil` to non-`nil` and vice versa, so that the caller can react to these changes.
  public func ifLet<Wrapped>(
    then unwrap: @escaping (Store<Wrapped, Action>) -> Void,
    else: @escaping () -> Void = {}
  ) -> Cancellable where State == Wrapped? {
    return self.state
      .removeDuplicates(by: { ($0 != nil) == ($1 != nil) })
      .sink { state in
        if var state = state {
          unwrap(
            self.scope {
              state = $0 ?? state
              return state
            }
          )
        } else {
          `else`()
        }
      }
  }

  /// Calls closure when a store's optional state is `nil`, and does so
  /// for as long as the cancellable lives.
  ///
  /// This method is useful for handling navigation in UIKit, but is to be used in cases when
  /// the state is of an optional enum (i.e. Destination enum) with multiple cases. The ifLet/else
  /// functionality is useful for when a view controller cannot push more than one view
  /// controller onto the navigation stack. If a view controller has the ability to push more than
  /// one view controller onto the stack, the ifLet/else use-case breaks down because the else
  /// case may pop a view controller from the stack that was just pushed within another subscriber
  /// closure.
  ///
  /// The follow demonstrates how to utilize this functionality:
  ///
  /// ```swift
  /// class ParentViewController: UIViewController {
  ///   let store: Store<ParentState, ParentAction>
  ///   var cancellables: Set<AnyCancellable> = []
  ///   ...
  ///   func viewDidLoad() {
  ///     ...
  ///     self.store
  ///       .scope(
  ///         state: { (/Parent.Destination.State.childState).extract(from: $0.destination) },
  ///         action: { .destination(.presented(.childAction($0))) }
  ///        )
  ///       .ifLet(
  ///         then: { [weak self] childStore in
  ///           self?.navigationController?.pushViewController(
  ///             ChildViewController(store: childStore),
  ///             animated: true
  ///           )
  ///         })
  ///       .store(in: &self.cancellables)
  ///
  ///     self.store
  ///       .scope(
  ///         state: \.destination,
  ///         action: { .destination($0) }
  ///        )
  ///       .ifNil(
  ///         then: { [weak self] childStore in
  ///           guard let self = self else { return }
  ///           self.navigationController?.popToViewController(self, animated: true)
  ///         })
  ///       .store(in: &self.cancellables)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - then: A function that is called when the store's optional state is `nil`
  /// - Returns: A cancellable that maintains a subscription to updates whenever the store's state
  ///   changes to `nil` , so that the caller can react to these changes.
  public func ifNil<Wrapped>(
    then: @escaping () -> Void = {}
  ) -> Cancellable where State == Wrapped? {
    return self.ifLet(then: { _ in }, else: then)
  }
}
