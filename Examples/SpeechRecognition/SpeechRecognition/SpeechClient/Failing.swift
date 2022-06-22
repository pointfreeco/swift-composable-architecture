import Combine
import ComposableArchitecture
import Speech
import XCTestDynamicOverlay

#if DEBUG
  extension SpeechClient {
    static let failing = Self(
      recognitionTask: { _ in
        XCTFail("\(Self.self).failing.recognitionTask was invoked")
        return AsyncStream { _ in }
      },
      requestAuthorization: {
        XCTFail("\(Self.self).failing.requestAuthorization was invoked")
        return .notDetermined
      }
    )
  }
#endif
