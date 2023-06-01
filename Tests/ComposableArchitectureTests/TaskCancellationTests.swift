import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

final class TaskCancellationTests: BaseTCATestCase {
  func testCancellation() async throws {
    enum CancelID { case task }
    let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
    let task = Task {
      try await withTaskCancellation(id: CancelID.task) {
        continuation.yield()
        continuation.finish()
        try await Task.never()
      }
    }
    await stream.first(where: { true })
    Task.cancel(id: CancelID.task)
    await Task.megaYield(count: 20)
    XCTAssertEqual(_cancellationCancellables.count, 0)
    do {
      try await task.cancellableValue
      XCTFail()
    } catch {
    }
  }

  func testWithTaskCancellationCleansUpTask() async throws {
    let task = Task {
      try await withTaskCancellation(id: 0) {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC * 1000)
      }
    }

    try await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
    XCTAssertEqual(_cancellationCancellables.count, 1)

    task.cancel()
    try await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
    XCTAssertEqual(_cancellationCancellables.count, 0)
  }
}
