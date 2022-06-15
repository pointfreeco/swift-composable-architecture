import ComposableArchitecture
import SwiftUI

@main
struct SpeechRecognitionApp: App {
  var body: some Scene {
    WindowGroup {
      SpeechRecognitionView(
        store: Store(
          initialState: .init(),
          reducer: AppReducer()
            .debug(actionFormat: .labelsOnly)
        )
      )
    }
  }
}
