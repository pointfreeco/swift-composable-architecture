import Combine
import ComposableArchitecture
import Speech
import XCTestDynamicOverlay

#if DEBUG
  extension SpeechClient {
    static let unimplemented = Self(
      finishTask: XCTUnimplemented("\(Self.self).finishTask"),
      requestAuthorization: XCTUnimplemented(
        "\(Self.self).requestAuthorization", placeholder: .notDetermined
      ),
      startTask: XCTUnimplemented(
        "\(Self.self).recognitionTask", placeholder: AsyncThrowingStream.never
      )
    )
  }
#endif
