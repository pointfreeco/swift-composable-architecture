import ComposableArchitecture
import SwiftUI
import UIKit

struct CaseStudy {
  let title: String
  let viewController: () -> UIViewController

  init(title: String, viewController: @autoclosure @escaping () -> UIViewController) {
    self.title = title
    self.viewController = viewController
  }
}

let dataSource: [CaseStudy] = [
  CaseStudy(
    title: "Basics",
    viewController: CounterViewController(
      store: Store(
        initialState: CounterState(),
        reducer: counterReducer,
        environment: CounterEnvironment()
      )
    )
  ),
  CaseStudy(
    title: "Lists",
    viewController: CountersTableViewController(
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
  ),
  CaseStudy(
    title: "Navigate and load",
    viewController: EagerNavigationViewController(
      store: Store(
        initialState: EagerNavigationState(),
        reducer: eagerNavigationReducer,
        environment: EagerNavigationEnvironment(
          mainQueue: .main
        )
      )
    )
  ),
  CaseStudy(
    title: "Load then navigate",
    viewController: LazyNavigationViewController(
      store: Store(
        initialState: LazyNavigationState(),
        reducer: lazyNavigationReducer,
        environment: LazyNavigationEnvironment(
          mainQueue: .main
        )
      )
    )
  ),
]

final class RootViewController: UITableViewController {
  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "Case Studies"
    self.navigationController?.navigationBar.prefersLargeTitles = true
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
    self.navigationController?.pushViewController(caseStudy.viewController(), animated: true)
  }
}

struct RootViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = UINavigationController(rootViewController: RootViewController())
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
