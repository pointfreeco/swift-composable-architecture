import ComposableArchitecture
import TwoFactorCore
import UIKit

@ViewAction(for: TwoFactor.self)
public final class TwoFactorViewController: UIViewController {
  public let store: StoreOf<TwoFactor>

  public init(store: StoreOf<TwoFactor>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .systemBackground

    let titleLabel = UILabel()
    titleLabel.text = "Enter the one time code to continue"
    titleLabel.textAlignment = .center

    let codeTextField = UITextField()
    codeTextField.placeholder = "1234"
    codeTextField.borderStyle = .roundedRect
    codeTextField.addTarget(
      self, action: #selector(codeTextFieldChanged(sender:)), for: .editingChanged)

    let loginButton = UIButton(type: .system)
    loginButton.setTitle("Login", for: .normal)
    loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)

    let activityIndicator = UIActivityIndicatorView(style: .large)
    activityIndicator.startAnimating()

    let rootStackView = UIStackView(arrangedSubviews: [
      titleLabel,
      codeTextField,
      loginButton,
      activityIndicator,
    ])
    rootStackView.isLayoutMarginsRelativeArrangement = true
    rootStackView.layoutMargins = .init(top: 0, left: 32, bottom: 0, right: 32)
    rootStackView.translatesAutoresizingMaskIntoConstraints = false
    rootStackView.axis = .vertical
    rootStackView.spacing = 24

    view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    var alertController: UIAlertController?

    observe { [weak self] in
      guard let self else { return }
      activityIndicator.isHidden = store.isActivityIndicatorHidden
      codeTextField.text = store.code
      loginButton.isEnabled = store.isLoginButtonEnabled

      if let store = store.scope(state: \.alert, action: \.alert),
        alertController == nil
      {
        alertController = UIAlertController(store: store)
        present(alertController!, animated: true, completion: nil)
      } else if store.alert == nil, alertController != nil {
        alertController?.dismiss(animated: true)
        alertController = nil
      }
    }
  }

  @objc private func codeTextFieldChanged(sender: UITextField) {
    store.code = sender.text ?? ""
  }

  @objc private func loginButtonTapped() {
    send(.submitButtonTapped)
  }
}

extension TwoFactor.State {
  fileprivate var isActivityIndicatorHidden: Bool { !isTwoFactorRequestInFlight }
  fileprivate var isLoginButtonEnabled: Bool { isFormValid && !isTwoFactorRequestInFlight }
}
