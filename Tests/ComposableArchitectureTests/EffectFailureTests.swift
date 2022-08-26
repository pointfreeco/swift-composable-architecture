import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class EffectFailureTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testTaskUnexpectedThrows() async {
    guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }

    XCTExpectFailure {
      $0.compactDescription == """
        An 'Effect.task' returned from "ComposableArchitectureTests/EffectFailureTests.swift:24" \
        threw an unhandled error. …

            EffectFailureTests.Unexpected()

        All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
        'Effect.task', or via a 'do' block.
        """
    }

    let effect = Effect<Void, Never>.task {
      struct Unexpected: Error {}
      throw Unexpected()
    }

    for await _ in effect.values {}
  }

  func testRunUnexpectedThrows() async {
    guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }

    XCTExpectFailure {
      $0.compactDescription == """
        An 'Effect.run' returned from "ComposableArchitectureTests/EffectFailureTests.swift:47" \
        threw an unhandled error. …

            EffectFailureTests.Unexpected()

        All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
        'Effect.run', or via a 'do' block.
        """
    }

    let effect = Effect<Void, Never>.run { _ in
      struct Unexpected: Error {}
      throw Unexpected()
    }

    for await _ in effect.values {}
  }
}
