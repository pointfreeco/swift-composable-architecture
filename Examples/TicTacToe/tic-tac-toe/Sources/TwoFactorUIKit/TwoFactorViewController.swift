import Combine
import ComposableArchitecture
import TwoFactorCore
import UIKit

public final class TwoFactorViewController: UIViewController {
  let store: StoreOf<TwoFactor>
  private var cancellables: Set<AnyCancellable> = []

  public init(store: StoreOf<TwoFactor>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    self.view.backgroundColor = .systemBackground

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

    self.view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
    ])

    self.store.publisher.isActivityIndicatorHidden
      .assign(to: \.isHidden, on: activityIndicator)
      .store(in: &self.cancellables)

    self.store.publisher.code
      .map(Optional.some)
      .assign(to: \.text, on: codeTextField)
      .store(in: &self.cancellables)

    self.store.publisher.isLoginButtonEnabled
      .assign(to: \.isEnabled, on: loginButton)
      .store(in: &self.cancellables)

    self.store.publisher.alert
      .sink { [weak self] alert in
        guard let self = self else { return }
        guard let alert = alert else { return }

        let alertController = UIAlertController(
          title: String(state: alert.title), message: nil, preferredStyle: .alert)
        alertController.addAction(
          UIAlertAction(title: "Ok", style: .default) { _ in
            self.store.send(.alert(.dismiss))
          }
        )
        self.present(alertController, animated: true, completion: nil)
      }
      .store(in: &self.cancellables)
  }

  @objc private func codeTextFieldChanged(sender: UITextField) {
    self.store.code = sender.text ?? ""
  }

  @objc private func loginButtonTapped() {
    self.store.send(.view(.submitButtonTapped))
  }
}

extension TwoFactor.State {
  fileprivate var isActivityIndicatorHidden: Bool { !self.isTwoFactorRequestInFlight }
  fileprivate var isLoginButtonEnabled: Bool {
    self.isFormValid && !self.isTwoFactorRequestInFlight
  }
}
