import Combine
import ComposableArchitecture
import GameUIKit
import NewGameCore
import UIKit

public class NewGameViewController: UIViewController {
  let store: StoreOf<NewGame>
  let viewStore: ViewStore<ViewState, ViewAction>
  private var cancellables: Set<AnyCancellable> = []

  struct ViewState: Equatable {
    let isGameActive: Bool
    let isLetsPlayButtonEnabled: Bool
    let oPlayerName: String?
    let xPlayerName: String?

    public init(state: NewGame.State) {
      self.isGameActive = state.game != nil
      self.isLetsPlayButtonEnabled = !state.oPlayerName.isEmpty && !state.xPlayerName.isEmpty
      self.oPlayerName = state.oPlayerName
      self.xPlayerName = state.xPlayerName
    }
  }

  enum ViewAction {
    case gameDismissed
    case letsPlayButtonTapped
    case logoutButtonTapped
    case oPlayerNameChanged(String?)
    case xPlayerNameChanged(String?)
  }

  public init(store: StoreOf<NewGame>) {
    self.store = store
    self.viewStore = ViewStore(store.scope(state: ViewState.init, action: NewGame.Action.init))
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "New Game"

    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "Logout",
      style: .done,
      target: self,
      action: #selector(logoutButtonTapped)
    )

    let playerXLabel = UILabel()
    playerXLabel.text = "Player X"
    playerXLabel.setContentHuggingPriority(.required, for: .horizontal)

    let playerXTextField = UITextField()
    playerXTextField.borderStyle = .roundedRect
    playerXTextField.placeholder = "Blob Sr."
    playerXTextField.setContentCompressionResistancePriority(.required, for: .horizontal)
    playerXTextField.addTarget(
      self, action: #selector(playerXTextChanged(sender:)), for: .editingChanged)

    let playerXRow = UIStackView(arrangedSubviews: [
      playerXLabel,
      playerXTextField,
    ])
    playerXRow.spacing = 24

    let playerOLabel = UILabel()
    playerOLabel.text = "Player O"
    playerOLabel.setContentHuggingPriority(.required, for: .horizontal)

    let playerOTextField = UITextField()
    playerOTextField.borderStyle = .roundedRect
    playerOTextField.placeholder = "Blob Jr."
    playerOTextField.setContentCompressionResistancePriority(.required, for: .horizontal)
    playerOTextField.addTarget(
      self, action: #selector(playerOTextChanged(sender:)), for: .editingChanged)

    let playerORow = UIStackView(arrangedSubviews: [
      playerOLabel,
      playerOTextField,
    ])
    playerORow.spacing = 24

    let letsPlayButton = UIButton(type: .system)
    letsPlayButton.setTitle("Let’s Play!", for: .normal)
    letsPlayButton.addTarget(self, action: #selector(letsPlayTapped), for: .touchUpInside)

    let rootStackView = UIStackView(arrangedSubviews: [
      playerXRow,
      playerORow,
      letsPlayButton,
    ])
    rootStackView.isLayoutMarginsRelativeArrangement = true
    rootStackView.layoutMargins = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32)
    rootStackView.translatesAutoresizingMaskIntoConstraints = false
    rootStackView.axis = .vertical
    rootStackView.spacing = 24

    self.view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
    ])

    self.viewStore.publisher.isLetsPlayButtonEnabled
      .assign(to: \.isEnabled, on: letsPlayButton)
      .store(in: &self.cancellables)

    self.viewStore.publisher.oPlayerName
      .assign(to: \.text, on: playerOTextField)
      .store(in: &self.cancellables)

    self.viewStore.publisher.xPlayerName
      .assign(to: \.text, on: playerXTextField)
      .store(in: &self.cancellables)

    self.store
      .scope(state: \.game, action: NewGame.Action.game)
      .ifLet(
        then: { [weak self] gameStore in
          self?.navigationController?.pushViewController(
            GameViewController(store: gameStore),
            animated: true
          )
        },
        else: { [weak self] in
          guard let self = self else { return }
          self.navigationController?.popToViewController(self, animated: true)
        }
      )
      .store(in: &self.cancellables)
  }

  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if !self.isMovingToParent {
      self.viewStore.send(.gameDismissed)
    }
  }

  @objc private func logoutButtonTapped() {
    self.viewStore.send(.logoutButtonTapped)
  }

  @objc private func playerXTextChanged(sender: UITextField) {
    self.viewStore.send(.xPlayerNameChanged(sender.text))
  }

  @objc private func playerOTextChanged(sender: UITextField) {
    self.viewStore.send(.oPlayerNameChanged(sender.text))
  }

  @objc private func letsPlayTapped() {
    self.viewStore.send(.letsPlayButtonTapped)
  }
}

extension NewGame.Action {
  init(action: NewGameViewController.ViewAction) {
    switch action {
    case .gameDismissed:
      self = .gameDismissed
    case .letsPlayButtonTapped:
      self = .letsPlayButtonTapped
    case .logoutButtonTapped:
      self = .logoutButtonTapped
    case let .oPlayerNameChanged(name):
      self = .oPlayerNameChanged(name ?? "")
    case let .xPlayerNameChanged(name):
      self = .xPlayerNameChanged(name ?? "")
    }
  }
}
