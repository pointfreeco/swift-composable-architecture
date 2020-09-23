import ComposableArchitecture
import SwiftUI
import UIKit

@main
struct FourTrackApp: App {
  var body: some Scene {
    WindowGroup {
      VoiceMemosView(
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
    }
  }
}
