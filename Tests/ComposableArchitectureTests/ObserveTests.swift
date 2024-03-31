#if swift(>=5.9)
  import Combine
  import ComposableArchitecture
  import XCTest

  final class ObserveTests: BaseTCATestCase {
    func testObserve() async throws {
      let model = Model()
      var counts: [Int] = []
      let observation = observe {
        counts.append(model.count)
      }
      XCTAssertEqual(counts, [0])
      model.count += 1
      try await Task.sleep(nanoseconds: 1_000_000)
      XCTAssertEqual(counts, [0, 1])
      _ = observation
    }

    func testCancellation() async throws {
      let model = Model()
      var counts: [Int] = []
      let observation = observe {
        counts.append(model.count)
      }
      XCTAssertEqual(counts, [0])
      observation.cancel()
      model.count += 1
      try await Task.sleep(nanoseconds: 1_000_000)
      XCTAssertEqual(counts, [0])
      _ = observation
    }
  }

  @Perceptible
  class Model {
    var count = 0
  }
#endif
