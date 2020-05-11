import AppCore
import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

struct UIKitAppView: UIViewControllerRepresentable {
  let store: Store<AppState, AppAction>

  func makeUIViewController(context: Context) -> AppViewController {
    AppViewController(store: store)
  }

  func updateUIViewController(
    _ uiViewController: AppViewController,
    context: Context
  ) {
    // Nothing to do
  }
}

class AppViewController: UINavigationController {
  let store: Store<AppState, AppAction>
  private var cancellables: Set<AnyCancellable> = []

  init(store: Store<AppState, AppAction>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.store
      .scope(state: { $0.login }, action: AppAction.login)
      .ifLet { [weak self] loginStore in
        self?.setViewControllers([LoginViewController(store: loginStore)], animated: false)
      }
      .store(in: &self.cancellables)

    self.store
      .scope(state: { $0.newGame }, action: AppAction.newGame)
      .ifLet { [weak self] newGameStore in
        self?.setViewControllers([NewGameViewController(store: newGameStore)], animated: false)
      }
      .store(in: &self.cancellables)
  }
}
