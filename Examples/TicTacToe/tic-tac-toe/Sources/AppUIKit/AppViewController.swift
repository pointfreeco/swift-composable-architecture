import AppCore
import ComposableArchitecture
import LoginUIKit
import NewGameUIKit
import SwiftUI
import UIKit

public struct UIKitAppView: UIViewControllerRepresentable {
  let store: StoreOf<TicTacToe>

  public init(store: StoreOf<TicTacToe>) {
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
  let store: StoreOf<TicTacToe>

  init(store: StoreOf<TicTacToe>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    observe { [weak self] in
      guard let self else { return }
      switch store.case {
      case let .login(store):
        setViewControllers([LoginViewController(store: store)], animated: false)
      case let .newGame(store):
        setViewControllers([NewGameViewController(store: store)], animated: false)
      }
    }
  }
}
