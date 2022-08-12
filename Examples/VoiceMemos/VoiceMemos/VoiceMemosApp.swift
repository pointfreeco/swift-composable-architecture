import ComposableArchitecture
import Foundation
import SwiftUI

@main
struct VoiceMemosApp: App {
  var body: some Scene {

    let _ = print(type(of: Text("").environment(\.font, .title)))

    WindowGroup {
VoiceMemosView(
  store: Store(
    initialState: VoiceMemos.State(),
    reducer: Reducer(
      VoiceMemos()
        .dependency(\.audioPlayer, .mock)
        .dependency(\.audioRecorder, .mock)
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
  static let defaultValue = { @Sendable in URL(fileURLWithPath: NSTemporaryDirectory()) }
}
extension DependencyValues {
  var temporaryDirectory: @Sendable () -> URL {
    get { self[TemporaryDirectoryKey.self] }
    set { self[TemporaryDirectoryKey.self] = newValue }
  }
}

private enum OpenSettingsKey: DependencyKey {
  static let defaultValue = { @Sendable @MainActor in
    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
  }
}
extension DependencyValues {
  var openSettings: @Sendable @MainActor () -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }
}
