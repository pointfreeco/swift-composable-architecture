import ComposableArchitecture
import GameUIKit
import NewGameCore
import UIKit

public class NewGameViewController: UIViewController {
  @UIBindable var store: StoreOf<NewGame>

  public init(store: StoreOf<NewGame>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = "New Game"
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "Logout",
      primaryAction: UIAction { [store] _ in store.send(.logoutButtonTapped) }
    )

    let playerXLabel = UILabel()
    playerXLabel.text = "Player X"
    playerXLabel.setContentHuggingPriority(.required, for: .horizontal)

    let playerXTextField = UITextField(text: $store.xPlayerName)
    playerXTextField.borderStyle = .roundedRect
    playerXTextField.placeholder = "Blob Sr."
    playerXTextField.setContentCompressionResistancePriority(.required, for: .horizontal)

    let playerXRow = UIStackView(arrangedSubviews: [
      playerXLabel,
      playerXTextField,
    ])
    playerXRow.spacing = 24

    let playerOLabel = UILabel()
    playerOLabel.text = "Player O"
    playerOLabel.setContentHuggingPriority(.required, for: .horizontal)

    let playerOTextField = UITextField(text: $store.oPlayerName)
    playerOTextField.borderStyle = .roundedRect
    playerOTextField.placeholder = "Blob Jr."
    playerOTextField.setContentCompressionResistancePriority(.required, for: .horizontal)

    let playerORow = UIStackView(arrangedSubviews: [
      playerOLabel,
      playerOTextField,
    ])
    playerORow.spacing = 24

    let letsPlayButton = UIButton(
      type: .system,
      primaryAction: UIAction { [store] _ in
        store.send(.letsPlayButtonTapped)
      })
    letsPlayButton.setTitle("Let’s Play!", for: .normal)

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

    view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    observe { [weak self] in
      guard let self else { return }
      letsPlayButton.isEnabled = store.isLetsPlayButtonEnabled
    }

    navigationDestination(item: $store.scope(state: \.game, action: \.game)) { store in
      GameViewController(store: store)
    }
  }
}

extension NewGame.State {
  fileprivate var isLetsPlayButtonEnabled: Bool {
    !oPlayerName.isEmpty && !xPlayerName.isEmpty
  }
}
