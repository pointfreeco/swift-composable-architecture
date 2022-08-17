import ComposableArchitecture
import Foundation
import SwiftUI

@main
struct VoiceMemosApp: App {
  var body: some Scene {
    WindowGroup {
      VoiceMemosView(
        store: Store(
          initialState: VoiceMemos.State(),
          reducer: Reducer(
            VoiceMemos(
              audioPlayer: .live,
              audioRecorder: .live,
              mainRunLoop: .main,
              openSettings: {
                await MainActor.run {
                  UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
              },
              temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
              uuid: { UUID() }
            )
          ).debug(),
          environment: ()
        )
      )
    }
  }
}
