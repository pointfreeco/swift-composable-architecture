import Combine
import ComposableArchitecture
import GameCore
import UIKit

public final class GameViewController: UIViewController {
  let store: StoreOf<Game>
  let viewStore: ViewStore<ViewState, Game.Action>
  private var cancellables: Set<AnyCancellable> = []

  struct ViewState: Equatable {
    let board: Three<Three<String>>
    let isGameEnabled: Bool
    let isPlayAgainButtonHidden: Bool
    let title: String?

    init(state: Game.State) {
      self.board = state.board.map { $0.map { $0?.label ?? "" } }
      self.isGameEnabled = !state.board.hasWinner && !state.board.isFilled
      self.isPlayAgainButtonHidden = !state.board.hasWinner && !state.board.isFilled
      self.title =
        state.board.hasWinner
        ? "Winner! Congrats \(state.currentPlayerName)!"
        : state.board.isFilled
          ? "Tied game!"
          : "\(state.currentPlayerName), place your \(state.currentPlayer.label)"
    }
  }

  public init(store: StoreOf<Game>) {
    self.store = store
    self.viewStore = ViewStore(store, observe: ViewState.init)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "Tic-Tac-Toe"
    self.view.backgroundColor = .systemBackground

    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "Quit",
      style: .done,
      target: self,
      action: #selector(quitButtonTapped)
    )

    let titleLabel = UILabel()
    titleLabel.textAlignment = .center

    let playAgainButton = UIButton(type: .system)
    playAgainButton.setTitle("Play again?", for: .normal)
    playAgainButton.addTarget(self, action: #selector(playAgainButtonTapped), for: .touchUpInside)

    let titleStackView = UIStackView(arrangedSubviews: [titleLabel, playAgainButton])
    titleStackView.axis = .vertical
    titleStackView.spacing = 12

    let gridCell11 = UIButton()
    gridCell11.addTarget(self, action: #selector(gridCell11Tapped), for: .touchUpInside)
    let gridCell21 = UIButton()
    gridCell21.addTarget(self, action: #selector(gridCell21Tapped), for: .touchUpInside)
    let gridCell31 = UIButton()
    gridCell31.addTarget(self, action: #selector(gridCell31Tapped), for: .touchUpInside)
    let gridCell12 = UIButton()
    gridCell12.addTarget(self, action: #selector(gridCell12Tapped), for: .touchUpInside)
    let gridCell22 = UIButton()
    gridCell22.addTarget(self, action: #selector(gridCell22Tapped), for: .touchUpInside)
    let gridCell32 = UIButton()
    gridCell32.addTarget(self, action: #selector(gridCell32Tapped), for: .touchUpInside)
    let gridCell13 = UIButton()
    gridCell13.addTarget(self, action: #selector(gridCell13Tapped), for: .touchUpInside)
    let gridCell23 = UIButton()
    gridCell23.addTarget(self, action: #selector(gridCell23Tapped), for: .touchUpInside)
    let gridCell33 = UIButton()
    gridCell33.addTarget(self, action: #selector(gridCell33Tapped), for: .touchUpInside)

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

    self.view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
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

    self.viewStore.publisher.title
      .assign(to: \.text, on: titleLabel)
      .store(in: &self.cancellables)

    self.viewStore.publisher.isPlayAgainButtonHidden
      .assign(to: \.isHidden, on: playAgainButton)
      .store(in: &self.cancellables)

    self.viewStore.publisher.map(\.board, \.isGameEnabled)
      .removeDuplicates(by: ==)
      .sink { board, isGameEnabled in
        board.enumerated().forEach { rowIdx, row in
          row.enumerated().forEach { colIdx, label in
            let button = cells[rowIdx][colIdx]
            button.setTitle(label, for: .normal)
            button.isEnabled = isGameEnabled
          }
        }
      }
      .store(in: &self.cancellables)
  }

  @objc private func gridCell11Tapped() { self.viewStore.send(.cellTapped(row: 0, column: 0)) }
  @objc private func gridCell12Tapped() { self.viewStore.send(.cellTapped(row: 0, column: 1)) }
  @objc private func gridCell13Tapped() { self.viewStore.send(.cellTapped(row: 0, column: 2)) }
  @objc private func gridCell21Tapped() { self.viewStore.send(.cellTapped(row: 1, column: 0)) }
  @objc private func gridCell22Tapped() { self.viewStore.send(.cellTapped(row: 1, column: 1)) }
  @objc private func gridCell23Tapped() { self.viewStore.send(.cellTapped(row: 1, column: 2)) }
  @objc private func gridCell31Tapped() { self.viewStore.send(.cellTapped(row: 2, column: 0)) }
  @objc private func gridCell32Tapped() { self.viewStore.send(.cellTapped(row: 2, column: 1)) }
  @objc private func gridCell33Tapped() { self.viewStore.send(.cellTapped(row: 2, column: 2)) }

  @objc private func quitButtonTapped() {
    self.viewStore.send(.quitButtonTapped)
  }

  @objc private func playAgainButtonTapped() {
    self.viewStore.send(.playAgainButtonTapped)
  }
}
