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
    ///   let viewStore: ViewStore<ViewState, ViewAction>
    ///   private var cancellables: Set<AnyCancellable> = []
    ///   private weak var alertController: UIAlertController?
    ///   ...
    ///   func viewDidLoad() {
    ///     ...
    ///     viewStore.publisher
    ///       .settingsAlert
    ///       .sink { [weak self] alert in
    ///         guard let self = self else { return }
    ///         if let alert = alert {
    ///           let alertController = UIAlertController(state: alert, send: {
    ///             self.viewStore.send(.settings($0))
    ///           })
    ///           self.present(alertController, animated: true, completion: nil)
    ///           self.alertController = alertController
    ///         } else {
    ///           self.alertController?.dismiss(animated: true, completion: nil)
    ///           self.alertController = nil
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
      send: @escaping (Action) -> Void
    ) {
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .alert
      )
      for button in state.buttons {
        self.addAction(button.toUIAlertAction(send: send))
      }
    }

    /// Creates a `UIAlertController` from `ConfirmationDialogState`.
    ///
    /// - Parameters:
    ///   - state: The state of dialog that can be shown to the user.
    ///   - send: A function that wraps a dialog action in the view store's action type.
    public convenience init<Action>(
      state: ConfirmationDialogState<Action>, send: @escaping (Action) -> Void
    ) {
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .actionSheet
      )
      state.buttons.forEach { button in
        self.addAction(button.toUIAlertAction(send: send))
      }
    }
  }

  @available(iOS 13, *)
  @available(macCatalyst 13, *)
  @available(macOS, unavailable)
  @available(tvOS 13, *)
  @available(watchOS, unavailable)
  extension AlertState.ButtonRole {
    var toUIKit: UIAlertAction.Style {
      switch self {
      case .cancel:
        return .cancel
      case .destructive:
        return .destructive
      }
    }
  }

  @available(iOS 13, *)
  @available(macCatalyst 13, *)
  @available(macOS, unavailable)
  @available(tvOS 13, *)
  @available(watchOS, unavailable)
  extension AlertState.Button {
    func toUIAlertAction(send: @escaping (Action) -> Void) -> UIAlertAction {
      let action = self.toSwiftUIAction(send: send)
      return UIAlertAction(
        title: String(state: self.label),
        style: self.role?.toUIKit ?? .default,
        handler: { _ in action() }
      )
    }
  }
#endif
