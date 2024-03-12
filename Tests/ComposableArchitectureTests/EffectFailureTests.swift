#if DEBUG
  import Combine
  @_spi(Internals) import ComposableArchitecture
  import XCTest

  final class EffectFailureTests: BaseTCATestCase {
    @MainActor
    func testRunUnexpectedThrows() async {
      guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }

      var line: UInt!
      XCTExpectFailure {
        $0.compactDescription == """
          An "Effect.run" returned from "\(#fileID):\(line+1)" threw an unhandled error. …

              EffectFailureTests.Unexpected()

          All non-cancellation errors must be explicitly handled via the "catch" parameter on \
          "Effect.run", or via a "do" block.
          """
      }

      line = #line
      let effect = Effect<Void>.run { _ in
        struct Unexpected: Error {}
        throw Unexpected()
      }

      for await _ in effect.actions {}
    }
  }
#endif
