import ComposableArchitecture
import TwoFactorCore
import UIKit

@ViewAction(for: TwoFactor.self)
public final class TwoFactorViewController: UIViewController {
  @UIBindable public var store: StoreOf<TwoFactor>

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

    let codeTextField = UITextField(text: $store.code)
    codeTextField.placeholder = "1234"
    codeTextField.borderStyle = .roundedRect

    let loginButton = UIButton(
      type: .system,
      primaryAction: UIAction { [weak self] _ in
        self?.send(.submitButtonTapped)
      })
    loginButton.setTitle("Login", for: .normal)

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

    observe { [weak self] in
      guard let self else { return }
      activityIndicator.isHidden = store.isActivityIndicatorHidden
      loginButton.isEnabled = store.isLoginButtonEnabled
    }

    present(item: $store.scope(state: \.alert, action: \.alert)) { store in
      UIAlertController(store: store)
    }
  }
}

extension TwoFactor.State {
  fileprivate var isActivityIndicatorHidden: Bool { !isTwoFactorRequestInFlight }
  fileprivate var isLoginButtonEnabled: Bool { isFormValid && !isTwoFactorRequestInFlight }
}
