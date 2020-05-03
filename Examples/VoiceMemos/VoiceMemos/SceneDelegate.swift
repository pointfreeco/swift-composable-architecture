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
      rootView: VoiceMemosView(
        store: Store(
          initialState: VoiceMemosState(),
          reducer: voiceMemosReducer.debug(),
          environment: VoiceMemosEnvironment(
            audioPlayerClient: .live,
            audioRecorderClient: .live,
            date: Date.init,
            mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
            openSettings: .fireAndForget {
              UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            },
            temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
            uuid: UUID.init
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
