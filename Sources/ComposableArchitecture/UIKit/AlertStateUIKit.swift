#if canImport(UIKit)
import UIKit

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension AlertState {
  /// UIKit helper generating UIAlertController from corresponding AlertState
  ///
  ///     class ParentViewController: UIViewController {
  ///        let store: Store<ParentState, ParentAction>
  ///        let viewStore: ViewStore<ViewState, ViewAction>
  ///        var cancellables: Set<AnyCancellable> = []
  ///        private weak var alertView: UIAlertController?
  ///        ...
  ///        func viewDidLoad() {
  ///          ...
  ///          viewStore.publisher
  ///            .settingsAlert
  ///            .sink { [weak self] alert in
  ///              guard let self = self else { return }
  ///              if let alert = alert {
  ///                let alertView = alert.toUIAlertController(send: {
  ///                  self.viewStore.send(.settings($0))
  ///                })
  ///                self.present(alertView, animated: true, completion: nil)
  ///                self.alertView = alertView
  ///              } else {
  ///                self.alertView?.dismiss(animated: true, completion: nil)
  ///                self.alertView = nil
  ///              }
  ///            }
  ///          .store(in: &cancellables)
  ///        }
  ///     }
  ///
  /// - Parameter send: A function that wraps a alert action in the view store's action type.
  /// - Returns: UIAlertController ready to presented by UIViewController.
  public func toUIAlertController(send: @escaping (Action) -> Void) -> UIAlertController {
    let alertController = UIAlertController(
      title: String(state: self.title),
      message: self.message.map { String(state: $0) },
      preferredStyle: .alert)

    if let primaryButton = self.primaryButton {
      alertController.addAction(primaryButton.toUIAlertAction(send: send))
    }

    if let secondaryButton = self.secondaryButton {
      alertController.addAction(secondaryButton.toUIAlertAction(send: send))
    }

    return alertController
  }
}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension AlertState.Button {
  func toUIAlertAction(send: @escaping (Action) -> Void) -> UIAlertAction {
    let action = { if let action = self.action { send(action) } }
    switch self.type {
    case let .cancel(.some(title)):
      return UIAlertAction(title: String(state: title), style: .cancel, handler: { _ in action() })
    case .cancel(.none):
      return UIAlertAction(title: nil, style: .cancel, handler: { _ in action() })
    case let .default(title):
      return UIAlertAction(title: String(state: title), style: .default, handler: { _ in action() })
    case let .destructive(title):
      return UIAlertAction(
        title: String(state: title), style: .destructive, handler: { _ in action() })
    }
  }
}
#endif
