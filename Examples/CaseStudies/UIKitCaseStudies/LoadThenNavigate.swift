import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

struct LazyNavigationState: Equatable {
  var optionalCounter: CounterState?
  var isActivityIndicatorHidden = true
}

enum LazyNavigationAction: Equatable {
  case onDisappear
  case optionalCounter(CounterAction)
  case setNavigation(isActive: Bool)
  case setNavigationIsActiveDelayCompleted
}

struct LazyNavigationEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let lazyNavigationReducer =
  counterReducer
  .optional()
  .pullback(
    state: \.optionalCounter,
    action: /LazyNavigationAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      LazyNavigationState, LazyNavigationAction, LazyNavigationEnvironment
    > { state, action, environment in

      enum CancelId {}

      switch action {
      case .onDisappear:
        return .cancel(id: CancelId.self)
      case .setNavigation(isActive: true):
        state.isActivityIndicatorHidden = false
        return Effect(value: .setNavigationIsActiveDelayCompleted)
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()
          .cancellable(id: CancelId.self)
      case .setNavigation(isActive: false):
        state.optionalCounter = nil
        return .none
      case .setNavigationIsActiveDelayCompleted:
        state.isActivityIndicatorHidden = true
        state.optionalCounter = CounterState()
        return .none
      case .optionalCounter:
        return .none
      }
    }
  )

class LazyNavigationViewController: UIViewController {
  var cancellables: [AnyCancellable] = []
  let store: Store<LazyNavigationState, LazyNavigationAction>
  let viewStore: ViewStore<LazyNavigationState, LazyNavigationAction>

  init(store: Store<LazyNavigationState, LazyNavigationAction>) {
    self.store = store
    self.viewStore = ViewStore(store)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "Load then navigate"

    self.view.backgroundColor = .systemBackground

    let button = UIButton(type: .system)
    button.addTarget(self, action: #selector(loadOptionalCounterTapped), for: .touchUpInside)
    button.setTitle("Load optional counter", for: .normal)

    let activityIndicator = UIActivityIndicatorView()
    activityIndicator.startAnimating()

    let rootStackView = UIStackView(arrangedSubviews: [
      button,
      activityIndicator,
    ])
    rootStackView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.centerXAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerXAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor),
    ])

    self.viewStore.publisher.isActivityIndicatorHidden
      .assign(to: \.isHidden, on: activityIndicator)
      .store(in: &self.cancellables)

    self.store
      .scope(state: \.optionalCounter, action: LazyNavigationAction.optionalCounter)
      .ifLet(
        then: { [weak self] store in
          self?.navigationController?.pushViewController(
            CounterViewController(store: store), animated: true)
        },
        else: { [weak self] in
          guard let self = self else { return }
          self.navigationController?.popToViewController(self, animated: true)
        }
      )
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

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.viewStore.send(.onDisappear)
  }
}

struct LazyNavigationViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = UINavigationController(
      rootViewController: LazyNavigationViewController(
        store: Store(
          initialState: LazyNavigationState(),
          reducer: lazyNavigationReducer,
          environment: LazyNavigationEnvironment(
            mainQueue: .main
          )
        )
      )
    )
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
