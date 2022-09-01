import ComposableArchitecture
import SwiftUI

@main
struct SpeechRecognitionApp: App {
  var body: some Scene {
    WindowGroup {
      SpeechRecognitionView(
        store: Store(
          initialState: AppState(),
          reducer:
            appReducer
            .debug(),
          environment: AppEnvironment(
            speechClient: .live
          )
        )
      )
    }
  }
}
