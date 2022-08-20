import XCTestDynamicOverlay

extension AudioPlayerClient {
  static let unimplemented = Self(
    play: XCTUnimplemented("\(Self.self).play")
  )
}
