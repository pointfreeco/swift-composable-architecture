#if DEBUG
  import Combine
  import ComposableArchitecture
  import XCTest

  @MainActor
  final class EffectFailureTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    func testTaskUnexpectedThrows() async {
      guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }

      var line: UInt!
      XCTExpectFailure {
        $0.compactDescription == """
          An "EffectTask.task" returned from "\(#fileID):\(line+1)" threw an unhandled error. …

              EffectFailureTests.Unexpected()

          All non-cancellation errors must be explicitly handled via the "catch" parameter on \
          "EffectTask.task", or via a "do" block.
          """
      }

      line = #line
      let effect = EffectTask<Void>.task {
        struct Unexpected: Error {}
        throw Unexpected()
      }

      for await _ in effect.values {}
    }

    func testRunUnexpectedThrows() async {
      guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }

      var line: UInt!
      XCTExpectFailure {
        $0.compactDescription == """
          An "EffectTask.run" returned from "\(#fileID):\(line+1)" threw an unhandled error. …

              EffectFailureTests.Unexpected()

          All non-cancellation errors must be explicitly handled via the "catch" parameter on \
          "EffectTask.run", or via a "do" block.
          """
      }

      line = #line
      let effect = EffectTask<Void>.run { _ in
        struct Unexpected: Error {}
        throw Unexpected()
      }

      for await _ in effect.values {}
    }
  }
#endif
