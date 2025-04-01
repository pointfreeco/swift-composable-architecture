import ComposableArchitecture
import SwiftUI

@main
struct SpeechRecognitionApp: App {
  static let store = Store(initialState: SpeechRecognition.State()) {
    SpeechRecognition()
      ._printChanges()
  }

  var body: some Scene {
    WindowGroup {
      SpeechRecognitionView(store: Self.store)
    }
  }
}
