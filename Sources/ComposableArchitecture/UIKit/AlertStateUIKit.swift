#if canImport(UIKit) && !os(watchOS)
  import UIKit

  @available(iOS 13, *)
  @available(macCatalyst 13, *)
  @available(macOS, unavailable)
  @available(tvOS 13, *)
  @available(watchOS, unavailable)
  extension UIAlertController {
    /// Creates a `UIAlertController` from `AlertState`.
    ///
    /// ```swift
    /// class ParentViewController: UIViewController {
    ///   let store: Store<ParentState, ParentAction>
    ///   private var cancellables: Set<AnyCancellable> = []
    ///   // ...
    ///   func viewDidLoad() {
    ///     // ...
    ///     var alertController: UIAlertController?
    ///     store.publisher
    ///       .settingsAlert
    ///       .sink { [weak self] alert in
    ///         guard let self else { return }
    ///         if let alert {
    ///           alertController = UIAlertController(state: alert) {
    ///             store.send(.settings($0))
    ///           }
    ///           present(alertController!, animated: true, completion: nil)
    ///         } else {
    ///           alertController?.dismiss(animated: true, completion: nil)
    ///           alertController = nil
    ///         }
    ///       }
    ///       .store(in: &cancellables)
    ///   }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - state: The state of an alert that can be shown to the user.
    ///   - send: A function that wraps an alert action in the view store's action type.
    public convenience init<Action>(
      state: AlertState<Action>,
      send: @escaping (_ action: Action?) -> Void
    ) {
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .alert
      )
      for button in state.buttons {
        self.addAction(.init(button, action: send))
      }
    }

    /// Creates a `UIAlertController` from a ``Store`` focused on alert state.
    ///
    /// You can use this initializer in tandem with ``ObjectiveC/NSObject/observe(_:)`` and
    /// ``Store/scope(state:action:)-36e72`` to drive an alert from state:
    ///
    /// ```swift
    /// class FeatureController: UIViewController {
    ///   let store: StoreOf<Feature>
    ///   private weak var alertController: UIAlertController?
    ///   // ...
    ///   func viewDidLoad() {
    ///     // ...
    ///     observe { [weak self] in
    ///       guard let self
    ///       else { return }
    ///
    ///       if
    ///         let store = store.scope(state: \.alert, action: \.alert),
    ///         alertController == nil
    ///       {
    ///         alertController = UIAlertController(store: store)
    ///         self.present(alertController!, animated: true, completion: nil)
    ///       } else if store.alert == nil, alertController != nil {
    ///         alertController?.dismiss(animated: true)
    ///         alertController = nil
    ///       }
    ///     }
    ///   }
    /// }
    /// ```
    public convenience init<Action>(
      store: Store<AlertState<Action>, PresentationAction<Action>>
    ) {
      let state = store.currentState
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .alert
      )
      for button in state.buttons {
        self.addAction(.init(button, action: { store.send($0.map { .presented($0) } ?? .dismiss) }))
      }
      if state.buttons.isEmpty {
        self.addAction(
          .init(
            title: "OK",
            style: .cancel,
            handler: { _ in store.send(.dismiss) })
        )
      }
    }

    /// Creates a `UIAlertController` from `ConfirmationDialogState`.
    ///
    /// - Parameters:
    ///   - state: The state of dialog that can be shown to the user.
    ///   - send: A function that wraps a dialog action in the view store's action type.
    public convenience init<Action>(
      state: ConfirmationDialogState<Action>, send: @escaping (_ action: Action?) -> Void
    ) {
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .actionSheet
      )
      for button in state.buttons {
        self.addAction(.init(button, action: send))
      }
    }

    /// Creates a `UIAlertController` from a ``Store`` focused on confirmation dialog state.
    ///
    /// You can use this initializer in tandem with ``ObjectiveC/NSObject/observe(_:)`` and
    /// ``Store/scope(state:action:)-36e72`` to drive an alert from state:
    ///
    /// ```swift
    /// class FeatureController: UIViewController {
    ///   let store: StoreOf<Feature>
    ///   private weak var alertController: UIAlertController?
    ///   // ...
    ///   func viewDidLoad() {
    ///     // ...
    ///     observe { [weak self] in
    ///       guard let self
    ///       else { return }
    ///
    ///       if
    ///         let store = store.scope(state: \.actionSheet, action: \.actionSheet),
    ///         alertController == nil
    ///       {
    ///         alertController = UIAlertController(store: store)
    ///         self.present(alertController!, animated: true, completion: nil)
    ///       } else if store.alert == nil, alertController != nil {
    ///         alertController?.dismiss(animated: true)
    ///         alertController = nil
    ///       }
    ///     }
    ///   }
    /// }
    /// ```
    public convenience init<Action>(
      store: Store<ConfirmationDialogState<Action>, PresentationAction<Action>>
    ) {
      let state = store.currentState
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .actionSheet
      )
      for button in state.buttons {
        self.addAction(.init(button, action: { store.send($0.map { .presented($0) } ?? .dismiss) }))
      }
      if state.buttons.isEmpty {
        self.addAction(
          .init(
            title: "OK",
            style: .cancel,
            handler: { _ in store.send(.dismiss) })
        )
      }
    }

  }

  @available(iOS 13, *)
  @available(macCatalyst 13, *)
  @available(macOS, unavailable)
  @available(tvOS 13, *)
  @available(watchOS, unavailable)
  extension UIAlertAction.Style {
    init(_ role: ButtonStateRole) {
      switch role {
      case .cancel:
        self = .cancel
      case .destructive:
        self = .destructive
      }
    }
  }

  @available(iOS 13, *)
  @available(macCatalyst 13, *)
  @available(macOS, unavailable)
  @available(tvOS 13, *)
  @available(watchOS, unavailable)
  extension UIAlertAction {
    convenience init<Action>(
      _ button: ButtonState<Action>,
      action handler: @escaping (_ action: Action?) -> Void
    ) {
      self.init(
        title: String(state: button.label),
        style: button.role.map(UIAlertAction.Style.init) ?? .default
      ) { _ in
        button.withAction(handler)
      }
    }
  }
#endif
