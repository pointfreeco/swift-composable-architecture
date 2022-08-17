import Combine
import XCTest

@testable import ComposableArchitecture

final class TaskCancellationTests: XCTestCase {
  func testCancellation() async throws {
    cancellationCancellables.removeAll()
    enum ID {}
    let (stream, continuation) = AsyncStream<Void>.streamWithContinuation()
    let task = Task {
      try await withTaskCancellation(id: ID.self) {
        continuation.yield()
        continuation.finish()
        try await Task.never()
      }
    }
    await stream.first(where: { true })
    await Task.cancel(id: ID.self)
    XCTAssertEqual(cancellationCancellables, [:])
    do {
      try await task.cancellableValue
      XCTFail()
    } catch {
    }
  }
}
