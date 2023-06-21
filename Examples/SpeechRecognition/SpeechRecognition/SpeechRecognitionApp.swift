import ComposableArchitecture
import SwiftUI

@main
struct SpeechRecognitionApp: App {
  var body: some Scene {
    WindowGroup {
      SpeechRecognitionView(
        store: Store(initialState: SpeechRecognition.State()) {
          SpeechRecognition()._printChanges()
        }
      )
    }
  }
}
