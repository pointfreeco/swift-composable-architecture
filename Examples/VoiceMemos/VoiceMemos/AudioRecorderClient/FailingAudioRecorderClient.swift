import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

#if DEBUG
  extension AudioRecorderClient {
    static let failing = Self(
      currentTime: {
        XCTFail("AudioRecorderClient.currentTime")
        return nil
      },
      requestRecordPermission: {
        XCTFail("AudioRecorderClient.requestRecordPermission")
        return false
      },
      startRecording: { _ in
        XCTFail("AudioRecorderClient.startRecording")
        return .init { _ in }
      },
      stopRecording: {
        XCTFail("AudioRecorderClient.stopRecording")
      }
    )
  }
#endif
