import ComposableArchitecture
import LoginCore
import TwoFactorUIKit
import UIKit

public class LoginViewController: UIViewController {
  let store: StoreOf<Login>

  public init(store: StoreOf<Login>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = "Login"
    view.backgroundColor = .systemBackground

    let disclaimerLabel = UILabel()
    disclaimerLabel.text = """
      To login use any email and "password" for the password. If your email contains the \
      characters "2fa" you will be taken to a two-factor flow, and on that screen you can use \
      "1234" for the code.
      """
    disclaimerLabel.textAlignment = .left
    disclaimerLabel.numberOfLines = 0

    let divider = UIView()
    divider.backgroundColor = .gray

    let titleLabel = UILabel()
    titleLabel.text = "Please log in to play TicTacToe!"
    titleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
    titleLabel.numberOfLines = 0

    let emailTextField = UITextField()
    emailTextField.placeholder = "email@address.com"
    emailTextField.borderStyle = .roundedRect
    emailTextField.autocapitalizationType = .none
    emailTextField.addTarget(
      self, action: #selector(emailTextFieldChanged(sender:)), for: .editingChanged
    )

    let passwordTextField = UITextField()
    passwordTextField.placeholder = "**********"
    passwordTextField.borderStyle = .roundedRect
    passwordTextField.addTarget(
      self, action: #selector(passwordTextFieldChanged(sender:)), for: .editingChanged
    )
    passwordTextField.isSecureTextEntry = true

    let loginButton = UIButton(type: .system)
    loginButton.setTitle("Login", for: .normal)
    loginButton.addTarget(self, action: #selector(loginButtonTapped(sender:)), for: .touchUpInside)

    let activityIndicator = UIActivityIndicatorView(style: .large)
    activityIndicator.startAnimating()

    let rootStackView = UIStackView(arrangedSubviews: [
      disclaimerLabel,
      divider,
      titleLabel,
      emailTextField,
      passwordTextField,
      loginButton,
      activityIndicator,
    ])
    rootStackView.isLayoutMarginsRelativeArrangement = true
    rootStackView.layoutMargins = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32)
    rootStackView.translatesAutoresizingMaskIntoConstraints = false
    rootStackView.axis = .vertical
    rootStackView.spacing = 24

    view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      divider.heightAnchor.constraint(equalToConstant: 1),
    ])

    var alertController: UIAlertController?
    var twoFactorViewController: TwoFactorViewController?

    observe { [weak self] in
      guard let self = self else { return }
      emailTextField.text = store.email
      emailTextField.isEnabled = store.isEmailTextFieldEnabled
      passwordTextField.text = store.password
      passwordTextField.isEnabled = store.isPasswordTextFieldEnabled
      loginButton.isEnabled = store.isLoginButtonEnabled
      activityIndicator.isHidden = store.isActivityIndicatorHidden

      if let alert = store.alert,
        alertController == nil
      {
        alertController = UIAlertController(
          title: String(state: alert.title),
          message: nil,
          preferredStyle: .alert
        )
        alertController?.addAction(
          UIAlertAction(title: "Ok", style: .default) { _ in
            self.store.send(.alert(.dismiss))
          }
        )
        present(alertController!, animated: true, completion: nil)
      } else if alertController != nil {
        alertController?.dismiss(animated: true)
        alertController = nil
      }

      if let store = store.scope(state: \.twoFactor, action: \.twoFactor.presented),
        twoFactorViewController == nil
      {
        twoFactorViewController = TwoFactorViewController(store: store)
        navigationController?.pushViewController(
          twoFactorViewController!,
          animated: true
        )
      } else if twoFactorViewController != nil {
        twoFactorViewController?.dismiss(animated: true)
        twoFactorViewController = nil
      }
    }
  }

  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if !isMovingToParent {
      store.send(.twoFactor(.dismiss))
    }
  }

  @objc private func loginButtonTapped(sender: UIButton) {
    store.send(.view(.loginButtonTapped))
  }

  @objc private func emailTextFieldChanged(sender: UITextField) {
    store.email = sender.text ?? ""
  }

  @objc private func passwordTextFieldChanged(sender: UITextField) {
    store.password = sender.text ?? ""
  }
}

extension Login.State {
  fileprivate var isActivityIndicatorHidden: Bool { !isLoginRequestInFlight }
  fileprivate var isEmailTextFieldEnabled: Bool { !isLoginRequestInFlight }
  fileprivate var isLoginButtonEnabled: Bool { isFormValid && !isLoginRequestInFlight }
  fileprivate var isPasswordTextFieldEnabled: Bool { !isLoginRequestInFlight }
}
