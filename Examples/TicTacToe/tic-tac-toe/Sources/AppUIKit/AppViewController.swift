import AppCore
import Combine
import ComposableArchitecture
import LoginUIKit
import NewGameUIKit
import SwiftUI
import UIKit

public struct UIKitAppView: UIViewControllerRepresentable {
  let store: StoreOf<AppReducer>

  public init(store: StoreOf<AppReducer>) {
    self.store = store
  }

  public func makeUIViewController(context: Context) -> UIViewController {
    AppViewController(store: store)
  }

  public func updateUIViewController(
    _ uiViewController: UIViewController,
    context: Context
  ) {
    // Nothing to do
  }
}

class AppViewController: UINavigationController {
  let store: StoreOf<AppReducer>
  private var cancellables: Set<AnyCancellable> = []

  init(store: StoreOf<AppReducer>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.store
      .scope(state: /AppReducer.State.login, action: AppReducer.Action.login)
      .ifLet { [weak self] loginStore in
        self?.setViewControllers([LoginViewController(store: loginStore)], animated: false)
      }
      .store(in: &self.cancellables)

    self.store
      .scope(state: /AppReducer.State.newGame, action: AppReducer.Action.newGame)
      .ifLet { [weak self] newGameStore in
        self?.setViewControllers([NewGameViewController(store: newGameStore)], animated: false)
      }
      .store(in: &self.cancellables)
  }
}
