import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

struct EagerNavigation: ReducerProtocol {
  struct State: Equatable {
    var isNavigationActive = false
    var optionalCounter: Counter.State?
  }

  enum Action: Equatable {
    case optionalCounter(Counter.Action)
    case setNavigation(isActive: Bool)
    case setNavigationIsActiveDelayCompleted
  }

  private enum CancelID {}
  @Dependency(\.continuousClock) var clock

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .setNavigation(isActive: true):
        state.isNavigationActive = true
        return .task {
          try await self.clock.sleep(for: .seconds(1))
          return .setNavigationIsActiveDelayCompleted
        }
        .cancellable(id: CancelID.self)

      case .setNavigation(isActive: false):
        state.isNavigationActive = false
        state.optionalCounter = nil
        return .cancel(id: CancelID.self)

      case .setNavigationIsActiveDelayCompleted:
        state.optionalCounter = Counter.State()
        return .none

      case .optionalCounter:
        return .none
      }
    }
  }
}

class EagerNavigationViewController: UIViewController {
  var cancellables: [AnyCancellable] = []
  let store: StoreOf<EagerNavigation>
  let viewStore: ViewStoreOf<EagerNavigation>

  init(store: StoreOf<EagerNavigation>) {
    self.store = store
    self.viewStore = ViewStore(store)
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

    self.viewStore.publisher.isNavigationActive.sink { [weak self] isNavigationActive in
      guard let self = self else { return }
      if isNavigationActive {
        self.navigationController?.pushViewController(
          IfLetStoreController(
            store: self.store
              .scope(state: \.optionalCounter, action: EagerNavigation.Action.optionalCounter)
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
      self.viewStore.send(.setNavigation(isActive: false))
    }
  }

  @objc private func loadOptionalCounterTapped() {
    self.viewStore.send(.setNavigation(isActive: true))
  }
}

struct EagerNavigationViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = UINavigationController(
      rootViewController: EagerNavigationViewController(
        store: Store(
          initialState: EagerNavigation.State(),
          reducer: EagerNavigation()
        )
      )
    )
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
