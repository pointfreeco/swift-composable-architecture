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

    self.window?.rootViewController = UIHostingController(
      rootView: SearchView(
        store: Store(
          initialState: SearchState(),
          reducer: searchReducer.debug(),
          environment: SearchEnvironment(
            weatherClient: WeatherClient.live,
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    )

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
