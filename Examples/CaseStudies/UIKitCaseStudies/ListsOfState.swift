import ComposableArchitecture
import UIKit

@Reducer
struct CounterList {
  @ObservableState
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

  init(store: StoreOf<CounterList>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Lists"

    tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    store.counters.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
  {
    let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
    cell.accessoryType = .disclosureIndicator
    observe { [weak self] in
      guard let self else { return }
      cell.textLabel?.text = "\(store.counters[indexPath.row].count)"
    }
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let id = store.counters[indexPath.row].id
    if let store = store.scope(state: \.counters[id:id], action: \.counters[id:id]) {
      navigationController?.pushViewController(CounterViewController(store: store), animated: true)
    }
  }
}

#Preview {
  UINavigationController(
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
}
