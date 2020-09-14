import ComposableArchitecture
import Combine
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    self.window = (scene as? UIWindowScene).map(UIWindow.init(windowScene:))
    self.window?.rootViewController = ViewController.init(store: Store(initialState: AppState(), reducer: reducer, environment: ()))
//      UINavigationController(
//      rootViewController: RootViewController())
    self.window?.makeKeyAndVisible()
  }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    true
  }
}

struct AppState: Equatable {
    var showView = false
}

enum AppAction {
    case showView
    case fetchSomeNecessaryData
}

let reducer = Reducer<AppState, AppAction, Void> { state, action, _ in
    switch action {
        case .showView:
            state.showView = true
            return .none

        case .fetchSomeNecessaryData:
            return .none
    }
}

final class ViewController: UIViewController {
    let store: Store<AppState, AppAction>
    let viewStore: ViewStore<AppState, AppAction>

    var cancellable: AnyCancellable?

    init(store: Store<AppState, AppAction>) {
        self.store = store
        self.viewStore = ViewStore(store)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .gray

        cancellable = viewStore.publisher.showView.sink { showView in
            guard showView else { return }
            self.present(
                DetailViewController(store: self.store),
                animated: true,
                completion: nil
            )
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        viewStore.send(.showView)
    }
}

final class DetailViewController: UIViewController {
    let viewStore: ViewStore<AppState, AppAction>

    init(store: Store<AppState, AppAction>) {
        self.viewStore = ViewStore(store)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        viewStore.send(.fetchSomeNecessaryData)
    }
}
