import ComposableArchitecture
import LoginCore
import TwoFactorUIKit
import UIKit

@ViewAction(for: Login.self)
public class LoginViewController: UIViewController {
  public let store: StoreOf<Login>

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
    var twoFactorController: TwoFactorViewController?

    observe { [weak self] in
      guard let self else { return }
      emailTextField.text = store.email
      emailTextField.isEnabled = store.isEmailTextFieldEnabled
      passwordTextField.text = store.password
      passwordTextField.isEnabled = store.isPasswordTextFieldEnabled
      loginButton.isEnabled = store.isLoginButtonEnabled
      activityIndicator.isHidden = store.isActivityIndicatorHidden

      if let store = store.scope(state: \.alert, action: \.alert),
        alertController == nil
      {
        alertController = UIAlertController(store: store)
        present(alertController!, animated: true, completion: nil)
      } else if store.alert == nil, alertController != nil {
        alertController?.dismiss(animated: true)
        alertController = nil
      }

      if let store = store.scope(state: \.twoFactor, action: \.twoFactor.presented),
        twoFactorController == nil
      {
        twoFactorController = TwoFactorViewController(store: store)
        navigationController?.pushViewController(
          twoFactorController!,
          animated: true
        )
      } else if store.twoFactor == nil, twoFactorController != nil {
        navigationController?.popToViewController(self, animated: true)
        twoFactorController = nil
      }
    }
  }

  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if !isMovingToParent {
      store.twoFactorDismissed()
    }
  }

  @objc private func loginButtonTapped(sender: UIButton) {
    send(.loginButtonTapped)
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

extension StoreOf<Login> {
  fileprivate func twoFactorDismissed() {
    send(.twoFactor(.dismiss))
  }
}
