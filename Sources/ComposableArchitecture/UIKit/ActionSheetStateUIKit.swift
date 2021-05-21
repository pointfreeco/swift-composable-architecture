#if canImport(UIKit)
import UIKit

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState {
  /// UIKit helper generating UIAlertController from corresponding ActionSheetState
  /// - Parameter send: A function that wraps a alert action in the view store's action type.
  /// - Returns: UIAlertController ready to presented by UIViewController.
  public func toUIAlertController(send: @escaping (Action) -> Void) -> UIAlertController {
    let alertController = UIAlertController(
      title: String(state: self.title),
      message: self.message.map { String(state: $0) },
      preferredStyle: .actionSheet
    )

    self.buttons.forEach { button in
      alertController.addAction(button.toUIAlertAction(send: send))
    }

    return alertController
  }
}
#endif
