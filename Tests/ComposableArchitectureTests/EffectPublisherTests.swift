import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class EffectPublisherTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []

  func testEscapedDependencies() {
    @Dependency(\.date.now) var now

    let effect = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
    } operation: {
      EffectTask.publisher {
        Just(now)
      }
    }

    var value: Date?
    effect.sink { value = $0 }.store(in: &self.cancellables)
    XCTAssertEqual(value, Date(timeIntervalSince1970: 1_234_567_890))
  }
}
