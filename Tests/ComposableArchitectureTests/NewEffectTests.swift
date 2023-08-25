import Combine
@testable @_spi(Canary)@_spi(Internals) import ComposableArchitecture
@testable import ComposableArchitecture
import XCTest

@MainActor
final class NewEffectTests: BaseTCATestCase {
  func testSyncForeverSyncSync() async throws {
    let effect = NewEffect<Int>.send(1)
      .concat(
        with: .escaping { send in
          DispatchQueue.main.async {
            send(2)
            send.finish()
          }
        }
      )
      .concat(with: .send(3))

    let values = LockIsolated([Int]())

    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1, 2, 3])
  }

  func testConcatenateNewStyle() async {
    let effect = NewEffect<Int>.send(1)
      .concat(with: .send(2))

    let values = LockIsolated<[Int]>([])
    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    XCTAssertEqual(values.value, [])
    await task.value
    XCTAssertEqual(values.value, [1, 2])
  }

  func testMergeNewStyle() async {
    let values = LockIsolated<[Int]>([])

    let effect = NewEffect<Int>.send(1).merge(with: .send(2))

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    XCTAssertEqual(values.value, [])
    await task.value
    XCTAssertEqual(values.value, [1, 2])
  }

  func testSend() async {
    let values = LockIsolated<[Int]>([])

    let effect = NewEffect<Int>.send(1)

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    XCTAssertEqual(values.value, [])
    await task.value
    XCTAssertEqual(values.value, [1])
  }

  func testSyncAsyncSync() async {
    let values = LockIsolated([Int]())

    let effect: NewEffect<Int> = .send(1)
      .concat(with: .async { $0(2) })
      .concat(with: .send(3))

    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1, 2, 3])
  }

  func testAsyncSyncSync() async {
    let values = LockIsolated([Int]())

    let effect: NewEffect<Int> = .async { $0(1) }
      .concat(with: .send(2))

    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1, 2])
  }

  func testAsyncSyncAsync() async {
    let values = LockIsolated([Int]())

    let effect: NewEffect<Int> = .async { $0(1) }
      .concat(with: .send(2))
      .concat(with: .async { $0(3) })

    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1, 2, 3])
  }


  func testConcatSyncWithAsync() async {
    let values = LockIsolated([Int]())

    let effect: NewEffect<Int> = .send(1)
      .concat(with: .async { $0(2) })

    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1, 2])
  }

  func testOnComplete_Publisher() async {
    let didComplete = LockIsolated(false)
    let effect = NewEffect<Int>.publisher { Just(1) }
      .onComplete { didComplete.setValue(true) }

    let values = LockIsolated([Int]())
    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1])
    XCTAssertEqual(didComplete.value, true)
  }

  func testOnComplete_Sync() async {
    let didComplete = LockIsolated(false)
    let effect = NewEffect<Int>.send(1)
      .onComplete { didComplete.setValue(true) }

    let values = LockIsolated([Int]())
    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1])
    XCTAssertEqual(didComplete.value, true)
  }

  func testOnComplete_Async() async {
    let didComplete = LockIsolated(false)
    let effect = NewEffect<Int>.async { $0(1) }
      .onComplete { didComplete.setValue(true) }

    let values = LockIsolated([Int]())
    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1])
    XCTAssertEqual(didComplete.value, true)
  }


  func testOnComplete_Multiple() async {
    let count = LockIsolated(0)
    let effect = NewEffect<Int>.async { $0(1) }
      .onComplete { count.withValue { $0 += 1 } }
      .onComplete { count.withValue { $0 += 1 } }

    let values = LockIsolated([Int]())
    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1])
    XCTAssertEqual(count.value, 2)
  }

  func testCancellation_Async() async throws {
    let effect = NewEffect<Int>.async { send in
      do {
        send(1)
        try await Task.sleep(for: .seconds(1))
        send(2)
      } catch {}
    }
      .cancellable(id: "id")

    let values = LockIsolated<[Int]>([])
    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    try await Task.sleep(for: .seconds(0.5))
    XCTAssertEqual(values.value, [1])

    Task.cancel(id: "id")
    await task.value
    XCTAssertEqual(values.value, [1])
    XCTAssertEqual(_cancellationCancellables.storage.isEmpty, true)
  }

  func testCancellation_Escaping() async throws {
    let effect = NewEffect<Int>.escaping { send in
      send(1)
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        send(2)
      }
    }
      .cancellable(id: "id")

    let values = LockIsolated<[Int]>([])
    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    try await Task.sleep(for: .seconds(0.5))
    XCTAssertEqual(values.value, [1])

    Task.cancel(id: "id")
    await task.value
    XCTAssertEqual(values.value, [1])
    XCTAssertEqual(_cancellationCancellables.storage.isEmpty, true)
  }
}
