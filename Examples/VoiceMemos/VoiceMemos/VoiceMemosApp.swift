import ComposableArchitecture
import SwiftUI

@main
struct VoiceMemosApp: App {
  
  @MainActor
  static let store = Store(initialState: VoiceMemos.State()) {
    VoiceMemos()
      ._printChanges()
  }
  
  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        VoiceMemosView(store: Self.store)
      }
    }
  }
}
