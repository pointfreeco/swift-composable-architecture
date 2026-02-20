#if DEBUG
  import Combine
  @_spi(Internals) import ComposableArchitecture
  import XCTest

  final class EffectFailureTests: BaseTCATestCase {
    @MainActor
    func testRunUnexpectedThrows() async {

      var line: UInt!
      XCTExpectFailure {
        $0.compactDescription.hasSuffix(
          """
          An "Effect.run" returned from "\(#fileID):\(line+1)" threw an unhandled error.

              EffectFailureTests.Unexpected()

          All non-cancellation errors must be explicitly handled via the "catch" parameter on \
          "Effect.run", or via a "do" block.
          """
        )
      }

      line = #line
      let effect = _Effect<Void>.run { _ in
        struct Unexpected: Error {}
        throw Unexpected()
      }

      for await _ in effect.actions {}
    }
  }
#endif
