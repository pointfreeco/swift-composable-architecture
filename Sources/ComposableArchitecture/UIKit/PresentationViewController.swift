import UIKit
import Combine

open class PresentationViewController: UIViewController, ViewControllerPresentable {
	public var onDismiss: (() -> Void)? = nil
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}
