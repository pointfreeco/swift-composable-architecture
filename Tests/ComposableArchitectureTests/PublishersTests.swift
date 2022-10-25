import Combine
import ComposableArchitecture
import XCTest

final class PublishersTests: XCTestCase {
  func testPublisherStream() async throws {
    let subject: CurrentValueSubject<Int, Never> = CurrentValueSubject(4)
    let stream = subject.stream
    let expectation = self.expectation(description: "subscription")
    let subscriptionTask = Task {
      var result = [Int]()
      for await value in stream {
        result.append(value)
        if value == 0 {
          break
        }
      }
      return result
    }

    subject.send(3)
    subject.send(2)
    subject.send(1)
    subject.send(0)
    let check = Task {
      let result = try await subscriptionTask.result.get()
      XCTAssertEqual(result, [4, 3, 2, 1, 0])
      expectation.fulfill()
    }
    self.wait(for: [expectation], timeout: 1.0)
    subscriptionTask.cancel()
    check.cancel()
  }

  func testPublisherThrowableStream() async throws {
    struct StreamError: Error {}
    let subject: CurrentValueSubject<Int, Error> = CurrentValueSubject(4)
    let stream = subject.stream
    let expectation = self.expectation(description: "throwing-subscription")

    let subscriptionTask = Task {
      var result = [Int]()
      for try await value in stream {
        result.append(value)
        if value == 0 {
          break
        }
      }
      return result
    }

    subject.send(3)
    subject.send(2)
    subject.send(1)
    subject.send(completion: .failure(StreamError()))

    let check = Task {
      switch await subscriptionTask.result {
      case let .failure(error):
        XCTAssert(error is StreamError)
        expectation.fulfill()
      case .success:
        XCTFail()
      }
    }
    self.wait(for: [expectation], timeout: 1.0)
    subscriptionTask.cancel()
    check.cancel()
  }
}
