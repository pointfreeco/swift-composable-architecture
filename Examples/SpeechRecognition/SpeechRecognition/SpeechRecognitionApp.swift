import ComposableArchitecture
import SwiftUI

@main
struct SpeechRecognitionApp: App {
  
  @MainActor
  static let store = Store(initialState: SpeechRecognition.State()) {
    SpeechRecognition()
      ._printChanges()
  }
  
  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        SpeechRecognitionView(store: Self.store)
      }
    }
  }
}
