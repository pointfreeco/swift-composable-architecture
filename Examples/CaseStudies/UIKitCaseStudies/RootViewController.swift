import ComposableArchitecture
import UIKit

struct CaseStudy {
  let title: String
  let viewController: () -> UIViewController

  init(title: String, viewController: @autoclosure @escaping () -> UIViewController) {
    self.title = title
    self.viewController = viewController
  }
}

@MainActor
let dataSource: [CaseStudy] = [
  CaseStudy(
    title: "Basics",
    viewController: CounterViewController(
      store: Store(initialState: Counter.State()) {
        Counter()
      }
    )
  ),
  CaseStudy(
    title: "Lists",
    viewController: CountersTableViewController(
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
  ),
  CaseStudy(
    title: "Navigate and load",
    viewController: EagerNavigationViewController(
      store: Store(initialState: EagerNavigation.State()) {
        EagerNavigation()
      }
    )
  ),
  CaseStudy(
    title: "Load then navigate",
    viewController: LazyNavigationViewController(
      store: Store(initialState: LazyNavigation.State()) {
        LazyNavigation()
      }
    )
  ),
]

final class RootViewController: UITableViewController {
  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Case Studies"
    navigationController?.navigationBar.prefersLargeTitles = true
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    dataSource.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
  {
    let caseStudy = dataSource[indexPath.row]
    let cell = UITableViewCell()
    cell.accessoryType = .disclosureIndicator
    cell.textLabel?.text = caseStudy.title
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let caseStudy = dataSource[indexPath.row]
    navigationController?.pushViewController(caseStudy.viewController(), animated: true)
  }
}

#Preview {
  UINavigationController(rootViewController: RootViewController())
}
