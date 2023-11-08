import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

@Reducer
struct EagerNavigation {
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
  var cancellables: [AnyCancellable] = []
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

    self.title = "Navigate and load"

    self.view.backgroundColor = .systemBackground

    let button = UIButton(type: .system)
    button.addTarget(self, action: #selector(loadOptionalCounterTapped), for: .touchUpInside)
    button.setTitle("Load optional counter", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(button)

    NSLayoutConstraint.activate([
      button.centerXAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerXAnchor),
      button.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor),
    ])

    self.store.publisher.isNavigationActive.sink { [weak self] isNavigationActive in
      guard let self = self else { return }
      if isNavigationActive {
        self.navigationController?.pushViewController(
          IfLetStoreController(
            self.store.scope(state: \.optionalCounter, action: { .optionalCounter($0) })
          ) {
            CounterViewController(store: $0)
          } else: {
            ActivityIndicatorViewController()
          },
          animated: true
        )
      } else {
        _ = self.navigationController?.popToViewController(self, animated: true)
      }
    }
    .store(in: &self.cancellables)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if !self.isMovingToParent {
      self.store.send(.setNavigation(isActive: false))
    }
  }

  @objc private func loadOptionalCounterTapped() {
    self.store.send(.setNavigation(isActive: true))
  }
}

struct EagerNavigationViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = UINavigationController(
      rootViewController: EagerNavigationViewController(
        store: Store(initialState: EagerNavigation.State()) {
          EagerNavigation()
        }
      )
    )
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
