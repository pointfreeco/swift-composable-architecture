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
        preferredStyle: .alert)

      if let primaryButton = state.primaryButton {
        self.addAction(primaryButton.toUIAlertAction(send: send))
      }

      if let secondaryButton = state.secondaryButton {
        self.addAction(secondaryButton.toUIAlertAction(send: send))
      }
    }

    /// Creates a `UIAlertController` from `ActionSheetState`.
    ///
    /// - Parameters:
    ///   - state: The state of an action sheet that can be shown to the user.
    ///   - send: A function that wraps a alert action in the view store's action type.
    public convenience init<Action>(
      state: ActionSheetState<Action>, send: @escaping (Action) -> Void
    ) {
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .actionSheet)

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
  extension AlertState.Button {
    func toUIAlertAction(send: @escaping (Action) -> Void) -> UIAlertAction {
      let action = {
        switch self.action?.type {
        case .none:
          return
        case let .some(.send(action)),
          let .some(.animatedSend(action, animation: _)):  // Doesn't support animation in UIKit
          send(action)
        }
      }
      switch self.type {
      case let .cancel(.some(title)):
        return UIAlertAction(
          title: String(state: title), style: .cancel, handler: { _ in action() })
      case .cancel(.none):
        return UIAlertAction(title: nil, style: .cancel, handler: { _ in action() })
      case let .default(title):
        return UIAlertAction(
          title: String(state: title), style: .default, handler: { _ in action() })
      case let .destructive(title):
        return UIAlertAction(
          title: String(state: title), style: .destructive, handler: { _ in action() })
      }
    }
  }
#endif
