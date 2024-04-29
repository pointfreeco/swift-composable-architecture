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

      model.otherCount += 1
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

    @MainActor
    func testNestedObservation() async throws {
      XCTExpectFailure {
        $0.compactDescription == """
          An "observe" was called from another "observe" closure, which can lead to \
          over-observation and unintended side effects.

          Avoid nested closures by moving child observation into their own lifecycle methods.
          """
      }

      let model = Model()
      var counts: [Int] = []
      var innerObservation: Any!
      let observation = observe { [weak self] in
        guard let self else { return }
        counts.append(model.count)
        innerObservation = observe {
          _ = model.otherCount
        }
      }
      defer {
        _ = observation
        _ = innerObservation
      }

      XCTAssertEqual(counts, [0])

      model.count += 1
      try await Task.sleep(nanoseconds: 1_000_000)
      XCTAssertEqual(counts, [0, 1])

      model.otherCount += 1
      try await Task.sleep(nanoseconds: 1_000_000)
      XCTAssertEqual(counts, [0, 1, 1])
    }
  }

  @Perceptible
  class Model {
    var count = 0
    var otherCount = 0
  }
#endif
