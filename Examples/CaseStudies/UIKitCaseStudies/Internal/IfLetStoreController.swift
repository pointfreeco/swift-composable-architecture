import Combine
import ComposableArchitecture
import UIKit

final class IfLetStoreController<State, Action>: UIViewController {
  let store: Store<State?, Action>
  let ifDestination: (Store<State, Action>) -> UIViewController
  let elseDestination: () -> UIViewController

  private var cancellables: Set<AnyCancellable> = []
  private var viewController = UIViewController() {
    willSet {
      viewController.willMove(toParent: nil)
      viewController.view.removeFromSuperview()
      viewController.removeFromParent()
      addChild(newValue)
      view.addSubview(newValue.view)
      newValue.didMove(toParent: self)
    }
  }

  init(
    _ store: Store<State?, Action>,
    then ifDestination: @escaping (Store<State, Action>) -> UIViewController,
    else elseDestination: @escaping () -> UIViewController
  ) {
    self.store = store
    self.ifDestination = ifDestination
    self.elseDestination = elseDestination
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    store.ifLet(
      then: { [weak self] store in
        guard let self else { return }
        viewController = ifDestination(store)
      },
      else: { [weak self] in
        guard let self else { return }
        viewController = elseDestination()
      }
    )
    .store(in: &cancellables)
  }
}
