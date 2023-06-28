import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

struct LazyNavigation: ReducerProtocol {
  struct State: Equatable {
    var optionalCounter: Counter.State?
    var isActivityIndicatorHidden = true
  }

  enum Action: Equatable {
    case onDisappear
    case optionalCounter(Counter.Action)
    case setNavigation(isActive: Bool)
    case setNavigationIsActiveDelayCompleted
  }

  private enum CancelID { case load }
  @Dependency(\.continuousClock) var clock

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .onDisappear:
        return .cancel(id: CancelID.load)

      case .setNavigation(isActive: true):
        state.isActivityIndicatorHidden = false
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.setNavigationIsActiveDelayCompleted)
        }
        .cancellable(id: CancelID.load)

      case .setNavigation(isActive: false):
        state.optionalCounter = nil
        return .none

      case .setNavigationIsActiveDelayCompleted:
        state.isActivityIndicatorHidden = true
        state.optionalCounter = Counter.State()
        return .none

      case .optionalCounter:
        return .none
      }
    }
    .ifLet(\.optionalCounter, action: /Action.optionalCounter) {
      Counter()
    }
  }
}

class LazyNavigationViewController: UIViewController {
  var cancellables: [AnyCancellable] = []
  let store: StoreOf<LazyNavigation>
  let viewStore: ViewStoreOf<LazyNavigation>

  init(store: StoreOf<LazyNavigation>) {
    self.store = store
    self.viewStore = ViewStore(store, observe: { $0 })
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
      .scope(state: \.optionalCounter, action: LazyNavigation.Action.optionalCounter)
      .ifLet(
        then: { [weak self] store in
          self?.navigationController?.pushViewController(
            CounterViewController(store: store), animated: true)
        },
        else: { [weak self] in
          guard let self = self else { return }
          _ = self.navigationController?.popToViewController(self, animated: true)
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
        store: Store(initialState: LazyNavigation.State()) {
          LazyNavigation()
        }
      )
    )
    return UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
