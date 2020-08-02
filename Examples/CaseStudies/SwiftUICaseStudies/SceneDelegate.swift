import SwiftUI
import UIKit
import Combine

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  var cancellable: AnyCancellable? 

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {


    self.cancellable = Publishers.Concatenate(
      prefix: Empty<Int, Never>(completeImmediately: true),
      suffix: Publishers.MergeMany(Empty(completeImmediately: true))
    )
      .print()
      .sink { _ in }


    self.window = (scene as? UIWindowScene).map(UIWindow.init(windowScene:))
    self.window?.rootViewController = UIHostingController(
      rootView: RootView(
        store: .init(
          initialState: RootState(),
          reducer: rootReducer,
          environment: .live
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
