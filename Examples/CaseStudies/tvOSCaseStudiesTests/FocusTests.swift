import ComposableArchitecture
import Testing

@testable import tvOSCaseStudies

@MainActor
@Test
func focus() async {
  let store = TestStore(initialState: Focus.State(currentFocus: 1)) {
    Focus()
  } withDependencies: {
    $0.withRandomNumberGenerator = .init(LCRNG())
  }

  await store.send(.randomButtonClicked)
  await store.send(.randomButtonClicked) {
    $0.currentFocus = 4
  }
  await store.send(.randomButtonClicked) {
    $0.currentFocus = 9
  }
}

/// A linear congruential random number generator.
struct LCRNG: RandomNumberGenerator {
  var seed: UInt64

  init(seed: UInt64 = 0) {
    self.seed = seed
  }

  mutating func next() -> UInt64 {
    self.seed = 2_862_933_555_777_941_757 &* self.seed &+ 3_037_000_493
    return self.seed
  }
}
