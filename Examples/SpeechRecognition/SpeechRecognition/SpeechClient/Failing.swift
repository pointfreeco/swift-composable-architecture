import Combine
import ComposableArchitecture
import Speech
import XCTestDynamicOverlay

#if DEBUG
  extension SpeechClient {
    static let failing = Self(
      finishTask: { XCTFail("\(Self.self).failing.finishTask was invoked") },
      recognitionTask: { _ in .failing("\(Self.self).recognitionTask") },
      requestAuthorization: {
        XCTFail("\(Self.self).failing.requestAuthorization was invoked")
        return .notDetermined
      }
    )
  }
#endif
