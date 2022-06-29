import Combine
import ComposableArchitecture
import Speech
import XCTestDynamicOverlay

#if DEBUG
  extension SpeechClient {
    static let unimplemented = Self(
      recognitionTask: XCTUnimplemented(
        // TODO: finish AsyncThrowingStream immediately
        "\(Self.self).recognitionTask", placeholder: AsyncThrowingStream { _ in }
      ),
      requestAuthorization: XCTUnimplemented(
        "\(Self.self).requestAuthorization", placeholder: .notDetermined
      )
    )
  }
#endif
