import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

struct EagerNavigationState: Equatable {
  var isNavigationActive = false
  var optionalCounter: CounterState?
}

enum EagerNavigationAction: Equatable {
  case optionalCounter(CounterAction)
  case setNavigation(isActive: Bool)
  case setNavigationIsActiveDelayCompleted
}

struct EagerNavigationEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let eagerNavigationReducer =
  counterReducer
  .optional()
  .pullback(
    state: \.optionalCounter,
    action: /EagerNavigationAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      EagerNavigationState, EagerNavigationAction, EagerNavigationEnvironment
    > { state, action, environment in

      enum CancelId {}

      switch action {
      case .setNavigation(isActive: true):
        state.isNavigationActive = true
        return Effect(value: .setNavigationIsActiveDelayCompleted)
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()
          .cancellable(id: CancelId.self)
      case .setNavigation(isActive: false):
        state.isNavigationActive = false
        state.optionalCounter = nil
        return .cancel(id: CancelId.self)
      case .setNavigationIsActiveDelayCompleted:
        state.optionalCounter = CounterState()
        return .none
      case .optionalCounter:
        return .none
      }
    }
  )

class EagerNavigationViewController: UIViewController {
  var cancellables: [AnyCancellable] = []
  let store: Store<EagerNavigationState, EagerNavigationAction>
  let viewStore: ViewStore<EagerNavigationState, EagerNavigationAction>

  init(store: Store<EagerNavigationState, EagerNavigationAction>) {
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
              .scope(state: \.optionalCounter, action: EagerNavigationAction.optionalCounter),
            then: CounterViewController.init(store:),
            else: ActivityIndicatorViewController.init
          ),
          animated: true
        )
      } else {
        self.navigationController?.popToViewController(self, animated: true)
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
          initialState: EagerNavigationState(),
          reducer: eagerNavigationReducer,
          environment: EagerNavigationEnvironment(
            mainQueue: .main
          )
        )
      )
    )
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
