import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

#if DEBUG
  extension AudioPlayerClient {
    static let failing = Self(
      play: XCTUnimplemented("\(Self.self).play")
    )
  }
#endif
