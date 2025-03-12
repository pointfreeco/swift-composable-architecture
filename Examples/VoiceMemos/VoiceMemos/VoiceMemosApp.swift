import ComposableArchitecture
import SwiftUI

@main
struct VoiceMemosApp: App {
  static let store = Store(initialState: VoiceMemos.State()) {
    VoiceMemos()
      ._printChanges()
  }

  var body: some Scene {
    WindowGroup {
      VoiceMemosView(store: Self.store)
    }
  }
}
