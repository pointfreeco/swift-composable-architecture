#if canImport(UIKit) && !os(watchOS)
  import UIKit

  @available(iOS 13, *)
  @available(macCatalyst 13, *)
  @available(macOS, unavailable)
  @available(tvOS 13, *)
  @available(watchOS, unavailable)
  extension UIAlertController {
    /// Creates a `UIAlertController` from a ``Store`` focused on alert state.
    ///
    /// You can use this API with the `UIViewController.present(item:)` method:
    ///
    /// ```swift
    /// class FeatureController: UIViewController {
    ///   @UIBindable var store: StoreOf<Feature>
    ///   // ...
    ///
    ///   func viewDidLoad() {
    ///     // ...
    ///
    ///     present(item: $store.scope(state: \.alert, action: \.alert)) { store in
    ///       UIAlertController(store: store)
    ///     }
    ///   }
    /// }
    /// ```
    public convenience init<Action>(
      store: Store<AlertState<Action>, Action>
    ) {
      let state = store.currentState
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .alert
      )
      for button in state.buttons {
        addAction(UIAlertAction(button, action: { _ = $0.map(store.send) }))
      }
      if state.buttons.isEmpty {
        addAction(UIAlertAction(title: "OK", style: .cancel))
      }
    }

    /// Creates a `UIAlertController` from a ``Store`` focused on confirmation dialog state.
    ///
    /// You can use this API with the `UIViewController.present(item:)` method:
    ///
    /// ```swift
    /// class FeatureController: UIViewController {
    ///   @UIBindable var store: StoreOf<Feature>
    ///   // ...
    ///
    ///   func viewDidLoad() {
    ///     // ...
    ///
    ///     present(item: $store.scope(state: \.dialog, action: \.dialog)) { store in
    ///       UIAlertController(store: store)
    ///     }
    ///   }
    /// }
    /// ```
    public convenience init<Action>(
      store: Store<ConfirmationDialogState<Action>, Action>
    ) {
      let state = store.currentState
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .actionSheet
      )
      for button in state.buttons {
        addAction(UIAlertAction(button, action: { _ = $0.map(store.send) }))
      }
      if state.buttons.isEmpty {
        addAction(UIAlertAction(title: "OK", style: .cancel))
      }
    }

  }
#endif
