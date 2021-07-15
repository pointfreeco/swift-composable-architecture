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
      rootView:
        VanillaPullToRefreshView(
          viewModel: .init(
            fetch: {
              await Task.sleep(2 * NSEC_PER_SEC)
              return String(
                decoding: try await URLSession.shared.data(
                  from: .init(string: "http://numbersapi.com/\($0)/trivia")!
                ).0,
                as: UTF8.self
              )
            }
          )
        )
//        RootView(
//        store: .init(
//          initialState: RootState(),
//          reducer: rootReducer,
//          environment: .live
//        )
//      )
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
