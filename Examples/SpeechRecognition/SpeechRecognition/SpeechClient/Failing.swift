import Combine
import ComposableArchitecture
import Speech
import XCTestDynamicOverlay

#if DEBUG
  extension SpeechClient {
    static let failing = Self(
      recognitionTask: XCTUnimplemented(
        "\(Self.self).recognitionTask", placeholder: AsyncThrowingStream { _ in }
      ),
      requestAuthorization: XCTUnimplemented(
        "\(Self.self).requestAuthorization", placeholder: .notDetermined
      )
    )
  }
#endif
