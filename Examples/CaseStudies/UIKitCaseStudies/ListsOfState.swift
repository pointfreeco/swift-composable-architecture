import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

@Reducer
struct CounterList {
  struct State: Equatable {
    var counters: IdentifiedArrayOf<Counter.State> = []
  }

  enum Action {
    case counters(IdentifiedActionOf<Counter>)
  }

  var body: some Reducer<State, Action> {
    EmptyReducer()
      .forEach(\.counters, action: \.counters) {
        Counter()
      }
  }
}

let cellIdentifier = "Cell"

final class CountersTableViewController: UITableViewController {
  let store: StoreOf<CounterList>
  let viewStore: ViewStoreOf<CounterList>
  var cancellables: Set<AnyCancellable> = []

  init(store: StoreOf<CounterList>) {
    self.store = store
    self.viewStore = ViewStore(store, observe: { $0 })
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
      .sink(receiveValue: { [weak self] _ in self?.tableView.reloadData() })
      .store(in: &self.cancellables)
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    self.viewStore.counters.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
  {
    let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
    cell.accessoryType = .disclosureIndicator
    cell.textLabel?.text = "\(self.viewStore.counters[indexPath.row].count)"
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let indexPathRow = indexPath.row
    let counter = self.viewStore.counters[indexPathRow]
    self.navigationController?.pushViewController(
      CounterViewController(
        store: self.store.scope(
          state: \.counters[indexPathRow],
          action: \.counters[id:counter.id]
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
          initialState: CounterList.State(
            counters: [
              Counter.State(),
              Counter.State(),
              Counter.State(),
            ]
          )
        ) {
          CounterList()
        }
      )
    )
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
