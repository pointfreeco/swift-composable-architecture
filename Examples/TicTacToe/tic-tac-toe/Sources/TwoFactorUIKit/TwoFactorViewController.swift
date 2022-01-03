import Combine
import ComposableArchitecture
import TwoFactorCore
import UIKit

public final class TwoFactorViewController: UIViewController {
  let store: Store<TwoFactorState, TwoFactorAction>
  let viewStore: ViewStore<ViewState, ViewAction>
  private var cancellables: Set<AnyCancellable> = []

  struct ViewState: Equatable {
    let alert: AlertState<TwoFactorAction>?
    let code: String?
    let isActivityIndicatorHidden: Bool
    let isLoginButtonEnabled: Bool

    init(state: TwoFactorState) {
      self.alert = state.alert
      self.code = state.code
      self.isActivityIndicatorHidden = !state.isTwoFactorRequestInFlight
      self.isLoginButtonEnabled = state.isFormValid && !state.isTwoFactorRequestInFlight
    }
  }

  enum ViewAction {
    case alertDismissed
    case codeChanged(String?)
    case loginButtonTapped
  }

  public init(store: Store<TwoFactorState, TwoFactorAction>) {
    self.store = store
    self.viewStore = ViewStore(store.scope(state: ViewState.init, action: TwoFactorAction.init))
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

    self.viewStore.publisher.isActivityIndicatorHidden
      .assign(to: \.isHidden, on: activityIndicator)
      .store(in: &self.cancellables)

    self.viewStore.publisher.code
      .assign(to: \.text, on: codeTextField)
      .store(in: &self.cancellables)

    self.viewStore.publisher.isLoginButtonEnabled
      .assign(to: \.isEnabled, on: loginButton)
      .store(in: &self.cancellables)

    self.viewStore.publisher.alert
      .sink { [weak self] alert in
        guard let self = self else { return }
        guard let alert = alert else { return }

        let alertController = UIAlertController(
          title: String(state: alert.title), message: nil, preferredStyle: .alert)
        alertController.addAction(
          UIAlertAction(title: "Ok", style: .default) { _ in
            self.viewStore.send(.alertDismissed)
          }
        )
        self.present(alertController, animated: true, completion: nil)
      }
      .store(in: &self.cancellables)
  }

  @objc private func codeTextFieldChanged(sender: UITextField) {
    self.viewStore.send(.codeChanged(sender.text))
  }

  @objc private func loginButtonTapped() {
    self.viewStore.send(.loginButtonTapped)
  }
}

extension TwoFactorAction {
  init(action: TwoFactorViewController.ViewAction) {
    switch action {
    case .alertDismissed:
      self = .alertDismissed
    case let .codeChanged(code):
      self = .codeChanged(code ?? "")
    case .loginButtonTapped:
      self = .submitButtonTapped
    }
  }
}
