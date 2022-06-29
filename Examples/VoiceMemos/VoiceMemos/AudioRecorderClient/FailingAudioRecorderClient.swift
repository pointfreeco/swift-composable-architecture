import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

#if DEBUG
  extension AudioRecorderClient {
    static let unimplemented = Self(
      currentTime: XCTUnimplemented("\(Self.self).currentTime", placeholder: nil),
      requestRecordPermission: XCTUnimplemented(
        "\(Self.self).requestRecordPermission", placeholder: false
      ),
      startRecording: XCTUnimplemented("\(Self.self).startRecording", placeholder: false),
      stopRecording: XCTUnimplemented("\(Self.self).stopRecording")
    )
  }
#endif
