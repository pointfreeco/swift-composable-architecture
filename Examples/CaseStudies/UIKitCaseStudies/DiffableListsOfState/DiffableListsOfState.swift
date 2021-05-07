import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

struct DiffableCounterListState: Equatable {
  var counters: IdentifiedArray<UUID, CounterState>
}

enum DiffableCounterListAction: Equatable {
  case counter(id: UUID, action: CounterAction)
  case shuffle
  case insert
  case remove(id: UUID)
}

let diffableCounterListReducer = Reducer<DiffableCounterListState, DiffableCounterListAction, Void>
  .combine(
    counterReducer
      .forEach(
        state: \DiffableCounterListState.counters,
        action: /DiffableCounterListAction.counter(id:action:),
        environment: { _ in .init() }
      ),
    Reducer { state, action, _ in
      switch action {
      case .shuffle:
        state.counters.shuffle()
        return .none
      case .insert:
        state.counters.append(.init())
        return .none
      case .remove(let id):
        state.counters.remove(id: id)
        return .none
      case .counter:
        return .none
      }
    }
  )

final class DiffableCountersTableViewController: UIViewController, UICollectionViewDelegate {

  struct DummySection: Hashable {}

  let store: Store<DiffableCounterListState, DiffableCounterListAction>
  let viewStore: ViewStore<DiffableCounterListState, DiffableCounterListAction>
  var cancellables: Set<AnyCancellable> = []

  var collectionView: UICollectionView!
  var dataSource: UICollectionViewDiffableDataSource<DummySection, CounterState.ID>!

  init(store: Store<DiffableCounterListState, DiffableCounterListAction>) {
    self.store = store
    self.viewStore = ViewStore(store)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "Diffable Lists"

    setUpCollectionView()
    setUpSubviews()

    collectionView.delegate = self
  }

  private func setUpSubviews() {
    let shuffle = UIButton(type: .roundedRect)
    shuffle.backgroundColor = .lightGray
    shuffle.setTitle("Shuffle", for: .normal)
    shuffle.addTarget(self, action: #selector(shuffleTapped), for: .touchUpInside)

    let insert = UIButton(type: .roundedRect)
    insert.backgroundColor = .lightGray
    insert.setTitle("Insert", for: .normal)
    insert.addTarget(self, action: #selector(insertTapped), for: .touchUpInside)

    let stackView = UIStackView(arrangedSubviews: [shuffle, insert])
    stackView.distribution = .fillEqually

    view.addSubview(collectionView)
    view.addSubview(stackView)

    collectionView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: stackView.topAnchor),
      stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    ])
  }

  private func setUpCollectionView() {
    var listConfiguration = UICollectionLayoutListConfiguration(appearance: .sidebarPlain)
    listConfiguration.trailingSwipeActionsConfigurationProvider = { indexPath in
      UISwipeActionsConfiguration(
        actions: [
          .init(
            style: .destructive,
            title: "Delete",
            handler: { [weak self] _, _, completion in
              guard let id = self?.dataSource.itemIdentifier(for: indexPath) else { return }
              self?.viewStore.send(.remove(id: id))
              completion(true)
            }
          )
        ]
      )
    }

    self.collectionView = UICollectionView(
      frame: view.frame,
      collectionViewLayout: UICollectionViewCompositionalLayout.list(using: listConfiguration)
    )

    self.collectionView.register(
      CounterCollectionViewCell.self,
      forCellWithReuseIdentifier: CounterCollectionViewCell.identifier
    )

    self.dataSource = .init(
      collectionView: collectionView,
      cellProvider: { [store] collectionView, indexPath, id in
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: CounterCollectionViewCell.identifier,
          for: indexPath
        ) as! CounterCollectionViewCell

        let childStore = store.child(
          id: id,
          state: \.counters,
          action: DiffableCounterListAction.counter(id:action:)
        )

        cell.viewStore = ViewStore(childStore)

        return cell
      }
    )

    self.viewStore.publisher.counters
      .sink(receiveValue: { [weak self] in
        var snapshot = NSDiffableDataSourceSnapshot<DummySection, CounterState.ID>()
        snapshot.appendSections([.init()])
        snapshot.appendItems($0.ids.elements)

        // check the window to prevent `UITableViewAlertForLayoutOutsideViewHierarchy` from firing
        // when not visible
        self?.dataSource.apply(
          snapshot,
          animatingDifferences: self?.view.window != nil ? true : false
        )
      })
      .store(in: &self.cancellables)
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let id = self.dataSource.itemIdentifier(for: indexPath) else { return }

    self.navigationController?.pushViewController(
      CounterViewController(
        store: self.store.child(
          id: id,
          state: \.counters,
          action: DiffableCounterListAction.counter(id:action:)
        )
      ),
      animated: true
    )
  }

  @objc func shuffleTapped() {
    self.viewStore.send(.shuffle)
  }

  @objc func insertTapped() {
    self.viewStore.send(.insert)
  }
}

extension Store {

  func child<LocalState: Equatable, LocalAction, ID>(
    id: ID,
    state toLocalStateContainer: @escaping (State) -> IdentifiedArray<ID, LocalState>,
    action fromLocalAction: @escaping (ID, LocalAction) -> Action
  ) -> Store<LocalState, LocalAction> {
    let scopedStore = scope(state: toLocalStateContainer)

    // NB: We cache current element here to avoid a crash where UIKit may re-evaluate the store
    //     following item deletion in table/collection views.
    let element = ViewStore(scopedStore).state[id: id]!

    return scopedStore.scope(
      state: { $0[id: id] ?? element },
      action: { fromLocalAction(id, $0) }
    )
  }
}

struct DiffableCountersTableViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = UINavigationController(
      rootViewController: DiffableCountersTableViewController(
        store: Store(
          initialState: DiffableCounterListState(
            counters: [
              CounterState(),
              CounterState(),
              CounterState(),
            ]
          ),
          reducer: diffableCounterListReducer,
          environment: ()
        )
      )
    )
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
