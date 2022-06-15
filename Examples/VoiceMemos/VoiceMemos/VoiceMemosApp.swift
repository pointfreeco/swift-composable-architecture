import ComposableArchitecture
import Foundation
import SwiftUI

@main
struct VoiceMemosApp: App {
  var body: some Scene {
    WindowGroup {
      VoiceMemosView(
        store: Store(
          initialState: .init(),
          reducer: VoiceMemos()
            .debug()
        )
      )
    }
  }
}
