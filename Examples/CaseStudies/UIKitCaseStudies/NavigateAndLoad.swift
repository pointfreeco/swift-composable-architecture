import ComposableArchitecture
import UIKit

@Reducer
struct EagerNavigation {
  @ObservableState
  struct State: Equatable {
    var isNavigationActive = false
    var optionalCounter: Counter.State?
  }

  enum Action {
    case optionalCounter(Counter.Action)
    case setNavigation(isActive: Bool)
    case setNavigationIsActiveDelayCompleted
  }

  private enum CancelID { case load }
  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .setNavigation(isActive: true):
        state.isNavigationActive = true
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.setNavigationIsActiveDelayCompleted)
        }
        .cancellable(id: CancelID.load)

      case .setNavigation(isActive: false):
        state.isNavigationActive = false
        state.optionalCounter = nil
        return .cancel(id: CancelID.load)

      case .setNavigationIsActiveDelayCompleted:
        state.optionalCounter = Counter.State()
        return .none

      case .optionalCounter:
        return .none
      }
    }
    .ifLet(\.optionalCounter, action: \.optionalCounter) {
      Counter()
    }
  }
}

class EagerNavigationViewController: UIViewController {
  let store: StoreOf<EagerNavigation>

  init(store: StoreOf<EagerNavigation>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Navigate and load"

    view.backgroundColor = .systemBackground

    let button = UIButton(type: .system)
    button.addTarget(self, action: #selector(loadOptionalCounterTapped), for: .touchUpInside)
    button.setTitle("Load optional counter", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(button)

    NSLayoutConstraint.activate([
      button.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
      button.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
    ])

    observe { [weak self] in
      guard let self else { return }
      if store.isNavigationActive {
        navigationController?.pushViewController(
          IfLetStoreController(
            store.scope(state: \.optionalCounter, action: \.optionalCounter)
          ) {
            CounterViewController(store: $0)
          } else: {
            ActivityIndicatorViewController()
          },
          animated: true
        )
      } else {
        navigationController?.popToViewController(self, animated: true)
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if !isMovingToParent && store.isNavigationActive {
      store.send(.setNavigation(isActive: false))
    }
  }

  @objc private func loadOptionalCounterTapped() {
    store.send(.setNavigation(isActive: true))
  }
}

#Preview {
  UINavigationController(
    rootViewController: EagerNavigationViewController(
      store: Store(initialState: EagerNavigation.State()) {
        EagerNavigation()
      }
    )
  )
}
