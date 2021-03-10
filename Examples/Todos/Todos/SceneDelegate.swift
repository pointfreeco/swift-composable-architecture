import ComposableArchitecture
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

    let rootView = AppView(
      store: Store(
        initialState: AppState(),
        reducer: appReducer,
        environment: AppEnvironment(
          analytics: .live,
          mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
          uuid: UUID.init
        )
      )
    )

    self.window?.rootViewController = UIHostingController(rootView: rootView)
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
