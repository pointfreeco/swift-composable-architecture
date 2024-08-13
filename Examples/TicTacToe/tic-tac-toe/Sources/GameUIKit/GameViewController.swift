import ComposableArchitecture
import GameCore
import UIKit

public final class GameViewController: UIViewController {
  let store: StoreOf<Game>

  public init(store: StoreOf<Game>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = "Tic-Tac-Toe"
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "Quit",
      primaryAction: UIAction { [store] _ in store.send(.quitButtonTapped) }
    )
    navigationItem.leftBarButtonItem?.style = .done

    view.backgroundColor = .systemBackground

    let titleLabel = UILabel()
    titleLabel.textAlignment = .center

    let playAgainButton = UIButton(
      type: .system,
      primaryAction: UIAction { [store] _ in
        store.send(.playAgainButtonTapped)
      })
    playAgainButton.setTitle("Play again?", for: .normal)

    let titleStackView = UIStackView(arrangedSubviews: [titleLabel, playAgainButton])
    titleStackView.axis = .vertical
    titleStackView.spacing = 12

    let gridCell11 = UIButton(
      primaryAction: UIAction { [store] _ in
        store.send(.cellTapped(row: 0, column: 0))
      })
    let gridCell21 = UIButton(
      primaryAction: UIAction { [store] _ in
        store.send(.cellTapped(row: 1, column: 0))
      })
    let gridCell31 = UIButton(
      primaryAction: UIAction { [store] _ in
        store.send(.cellTapped(row: 2, column: 0))
      })
    let gridCell12 = UIButton(
      primaryAction: UIAction { [store] _ in
        store.send(.cellTapped(row: 0, column: 1))
      })
    let gridCell22 = UIButton(
      primaryAction: UIAction { [store] _ in
        store.send(.cellTapped(row: 1, column: 1))
      })
    let gridCell32 = UIButton(
      primaryAction: UIAction { [store] _ in
        store.send(.cellTapped(row: 2, column: 1))
      })
    let gridCell13 = UIButton(
      primaryAction: UIAction { [store] _ in
        store.send(.cellTapped(row: 0, column: 2))
      })
    let gridCell23 = UIButton(
      primaryAction: UIAction { [store] _ in
        store.send(.cellTapped(row: 1, column: 2))
      })
    let gridCell33 = UIButton(
      primaryAction: UIAction { [store] _ in
        store.send(.cellTapped(row: 2, column: 2))
      })

    let cells = [
      [gridCell11, gridCell12, gridCell13],
      [gridCell21, gridCell22, gridCell23],
      [gridCell31, gridCell32, gridCell33],
    ]

    let gameRow1StackView = UIStackView(arrangedSubviews: cells[0])
    gameRow1StackView.spacing = 6
    let gameRow2StackView = UIStackView(arrangedSubviews: cells[1])
    gameRow2StackView.spacing = 6
    let gameRow3StackView = UIStackView(arrangedSubviews: cells[2])
    gameRow3StackView.spacing = 6

    let gameStackView = UIStackView(arrangedSubviews: [
      gameRow1StackView,
      gameRow2StackView,
      gameRow3StackView,
    ])
    gameStackView.axis = .vertical
    gameStackView.spacing = 6

    let rootStackView = UIStackView(arrangedSubviews: [
      titleStackView,
      gameStackView,
    ])
    rootStackView.isLayoutMarginsRelativeArrangement = true
    rootStackView.layoutMargins = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32)
    rootStackView.translatesAutoresizingMaskIntoConstraints = false
    rootStackView.axis = .vertical
    rootStackView.spacing = 100

    view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    gameStackView.arrangedSubviews
      .flatMap { view in (view as? UIStackView)?.arrangedSubviews ?? [] }
      .enumerated()
      .forEach { idx, cellView in
        cellView.backgroundColor = idx % 2 == 0 ? .darkGray : .lightGray
        NSLayoutConstraint.activate([
          cellView.widthAnchor.constraint(equalTo: cellView.heightAnchor)
        ])
      }

    observe { [weak self] in
      guard let self else { return }
      titleLabel.text = store.title
      playAgainButton.isHidden = store.isPlayAgainButtonHidden

      for (rowIdx, row) in store.rows.enumerated() {
        for (colIdx, label) in row.enumerated() {
          let button = cells[rowIdx][colIdx]
          button.setTitle(label, for: .normal)
          button.isEnabled = store.isGameEnabled
        }
      }
    }
  }
}

extension Game.State {
  fileprivate var rows: Three<Three<String>> { self.board.map { $0.map { $0?.label ?? "" } } }
  fileprivate var isGameEnabled: Bool { !self.board.hasWinner && !self.board.isFilled }
  fileprivate var isPlayAgainButtonHidden: Bool { !self.board.hasWinner && !self.board.isFilled }
  fileprivate var title: String {
    self.board.hasWinner
      ? "Winner! Congrats \(self.currentPlayerName)!"
      : self.board.isFilled
        ? "Tied game!"
        : "\(self.currentPlayerName), place your \(self.currentPlayer.label)"
  }
}
