import ComposableArchitecture
import LoginCore
import TwoFactorUIKit
import UIKit

@ViewAction(for: Login.self)
public class LoginViewController: UIViewController {
  @UIBindable public var store: StoreOf<Login>

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

    let emailTextField = UITextField(text: $store.email)
    emailTextField.placeholder = "email@address.com"
    emailTextField.borderStyle = .roundedRect
    emailTextField.autocapitalizationType = .none

    let passwordTextField = UITextField(text: $store.password)
    passwordTextField.placeholder = "**********"
    passwordTextField.borderStyle = .roundedRect
    passwordTextField.isSecureTextEntry = true

    let loginButton = UIButton(
      type: .system,
      primaryAction: UIAction { [weak self] _ in
        self?.send(.loginButtonTapped)
      })
    loginButton.setTitle("Login", for: .normal)

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
    rootStackView.axis = .vertical
    rootStackView.layoutMargins = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32)
    rootStackView.isLayoutMarginsRelativeArrangement = true
    rootStackView.spacing = 24
    rootStackView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      divider.heightAnchor.constraint(equalToConstant: 1),
    ])

    observe { [weak self, weak emailTextField, weak passwordTextField] in
      guard let self else { return }
      emailTextField?.isEnabled = store.isEmailTextFieldEnabled
      passwordTextField?.isEnabled = store.isPasswordTextFieldEnabled
      loginButton.isEnabled = store.isLoginButtonEnabled
      activityIndicator.isHidden = store.isActivityIndicatorHidden
    }

    present(item: $store.scope(state: \.alert, action: \.alert)) { store in
      UIAlertController(store: store)
    }

    navigationDestination(item: $store.scope(state: \.twoFactor, action: \.twoFactor)) { store in
      TwoFactorViewController(store: store)
    }
  }
}

extension Login.State {
  fileprivate var isActivityIndicatorHidden: Bool { !isLoginRequestInFlight }
  fileprivate var isEmailTextFieldEnabled: Bool { !isLoginRequestInFlight }
  fileprivate var isLoginButtonEnabled: Bool { isFormValid && !isLoginRequestInFlight }
  fileprivate var isPasswordTextFieldEnabled: Bool { !isLoginRequestInFlight }
}
