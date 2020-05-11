import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

struct CounterListState: Equatable {
  var counters: [CounterState] = []
}

enum CounterListAction: Equatable {
  case counter(index: Int, action: CounterAction)
}

struct CounterListEnvironment {}

let counterListReducer: Reducer<CounterListState, CounterListAction, CounterListEnvironment> =
  counterReducer.forEach(
    state: \CounterListState.counters,
    action: /CounterListAction.counter(index:action:),
    environment: { _ in CounterEnvironment() }
  )

let cellIdentifier = "Cell"

final class CountersTableViewController: UITableViewController {
  let store: Store<CounterListState, CounterListAction>
  let viewStore: ViewStore<CounterListState, CounterListAction>
  var cancellables: Set<AnyCancellable> = []

  var dataSource: [CounterState] = [] {
    didSet { self.tableView.reloadData() }
  }

  init(store: Store<CounterListState, CounterListAction>) {
    self.store = store
    self.viewStore = ViewStore(store)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "Lists"

    self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

    self.viewStore.publisher.counters
      .sink(receiveValue: { [weak self] in self?.dataSource = $0 })
      .store(in: &self.cancellables)
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    self.dataSource.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
  {
    let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
    cell.accessoryType = .disclosureIndicator
    cell.textLabel?.text = "\(self.dataSource[indexPath.row].count)"
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.navigationController?.pushViewController(
      CounterViewController(
        store: self.store.scope(
          state: { $0.counters[indexPath.row] },
          action: { .counter(index: indexPath.row, action: $0) }
        )
      ),
      animated: true
    )
  }
}

struct CountersTableViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = UINavigationController(
      rootViewController: CountersTableViewController(
        store: Store(
          initialState: CounterListState(
            counters: [
              CounterState(),
              CounterState(),
              CounterState(),
            ]
          ),
          reducer: counterListReducer,
          environment: CounterListEnvironment()
        )
      )
    )
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
