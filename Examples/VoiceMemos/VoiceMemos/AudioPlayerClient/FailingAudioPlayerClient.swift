import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

#if DEBUG
  extension AudioPlayerClient {
    private struct Failing: Error { let endpoint: String }

    static let failing = Self(
      play: { _ in
        XCTFail("\(Self.self).failing.play was invoked")
        throw Failing(endpoint: "play")
      }
    )
  }
#endif
