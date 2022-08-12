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

import XCTestDynamicOverlay
private enum TemporaryDirectoryKey: DependencyKey {
  static let liveValue = { @Sendable in URL(fileURLWithPath: NSTemporaryDirectory()) }
  static let testValue: @Sendable () -> URL = XCTUnimplemented(
    #"Unimplemented: @Dependency(\.temporaryDirectory)"#,
    placeholder: URL(fileURLWithPath: NSTemporaryDirectory())
  )
}
extension DependencyValues {
  var temporaryDirectory: @Sendable () -> URL {
    get { self[TemporaryDirectoryKey.self] }
    set { self[TemporaryDirectoryKey.self] = newValue }
  }
}

private enum OpenSettingsKey: DependencyKey {
  static let liveValue = { @Sendable in
    _ = await UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
  }
  static let testValue: @Sendable () async -> Void = XCTUnimplemented(
    #"Unimplemented: @Dependency(\.openSettings)"#
  )
}
extension DependencyValues {
  var openSettings: @Sendable () async -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }
}
