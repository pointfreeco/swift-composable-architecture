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
      VoiceMemos()
//      (
//        audioPlayer: .live,
//        audioRecorder: .live,
//        mainRunLoop: .main,
//        openSettings: { @MainActor in
//          UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
//        },
//        temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
//        uuid: { UUID() }
//      )
    )
    .debug(),
    environment: ()
  )
)
    }
  }
}

private enum TemporaryDirectoryKey: DependencyKey {
  static let defaultValue = { URL(fileURLWithPath: NSTemporaryDirectory()) }
}
extension DependencyValues {
  var temporaryDirectory: () -> URL {
    get { self[TemporaryDirectoryKey.self] }
    set { self[TemporaryDirectoryKey.self] = newValue }
  }
}

private enum OpenSettingsKey: DependencyKey {
  static let defaultValue = { @MainActor in
    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
  }
}
extension DependencyValues {
  var openSettings: @MainActor () -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }
}
