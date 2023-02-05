import ComposableArchitecture
import SwiftUI

@main
struct VoiceMemosApp: App {
  var body: some Scene {
    WindowGroup {
      VoiceMemosView(
        store: Store(
          initialState: VoiceMemos.State(),
          reducer: VoiceMemos()._printChanges()
        )
      )
    }
  }
}
