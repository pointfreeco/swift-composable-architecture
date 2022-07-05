import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class EffectFailureTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testTaskUnexpectedThrows() {
    XCTExpectFailure {
      Effect<Void, Never>.task {
        struct Unexpected: Error {}
        throw Unexpected()
      }
      .sink { _ in }
      .store(in: &self.cancellables)

      _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
    } issueMatcher: {
      $0.compactDescription == """
        An 'Effect.task' returned from "ComposableArchitectureTests/EffectFailureTests.swift:11" \
        threw an unhandled error:

          EffectFailureTests.Unexpected()

        All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
        'Effect.task', or via a 'do' block.
        """
    }
  }

  func testRunUnexpectedThrows() {
    XCTExpectFailure {
      Effect<Void, Never>.run { _ in
        struct Unexpected: Error {}
        throw Unexpected()
      }
      .sink { _ in }
      .store(in: &self.cancellables)

      _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
    } issueMatcher: {
      $0.compactDescription == """
        An 'Effect.run' returned from "ComposableArchitectureTests/EffectFailureTests.swift:34" \
        threw an unhandled error:

          EffectFailureTests.Unexpected()

        All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
        'Effect.run', or via a 'do' block.
        """
    }
  }
}
