import Combine
import ComposableArchitecture
import XCTest

final class MemoryManagementTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []

  @available(*, deprecated)
  @MainActor
  func testOwnership_ScopeHoldsOntoParent() {
    let counterReducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }
    let store = Store(initialState: 0) { counterReducer }
      .scope(state: { "\($0)" }, action: { $0 })
      .scope(state: { Int($0)! }, action: { $0 })
    let viewStore = ViewStore(store, observe: { $0 })

    var count = 0
    viewStore.publisher.sink { count = $0 }.store(in: &self.cancellables)

    XCTAssertEqual(count, 0)
    viewStore.send(())
    XCTAssertEqual(count, 1)
  }

  @available(*, deprecated)
  @MainActor
  func testOwnership_ViewStoreHoldsOntoStore() {
    let counterReducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }
    let viewStore = ViewStore(Store(initialState: 0) { counterReducer }, observe: { $0 })

    var count = 0
    viewStore.publisher.sink { count = $0 }.store(in: &self.cancellables)

    XCTAssertEqual(count, 0)
    viewStore.send(())
    XCTAssertEqual(count, 1)
  }

  @available(*, deprecated)
  @MainActor
  func testEffectWithMultipleScopes() {
    let expectation = self.expectation(description: "")

    enum Action { case tap, response }
    let store = Store(initialState: false) {
      Reduce<Bool, Action> { state, action in
        switch action {
        case .tap:
          state = false
          return .send(.response)
        case .response:
          state = true
          return .run { _ in
            expectation.fulfill()
          }
        }
      }
    }
    let viewStore = ViewStore(
      store
        .scope(state: { $0 }, action: { $0 })
        .scope(state: { $0 }, action: { $0 }),
      observe: { $0 }
    )

    var values: [Bool] = []
    viewStore.publisher
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [false])
    viewStore.send(.tap)
    self.wait(for: [expectation], timeout: 1)
    XCTAssertEqual(values, [false, true])
  }

  #if canImport(Darwin)
    @MainActor
    func testLongLivingEffectReleasesFinishedChildTasks() async throws {
      enum Action { case start, child }
      let (children, sendChild) = AsyncStream.makeStream(of: Void.self)
      let finished = LockIsolated(0)
      let store = Store(initialState: 0) {
        Reduce<Int, Action> { _, action in
          switch action {
          case .start:
            return .run { send in
              for await _ in children {
                await send(.child)
              }
            }
          case .child:
            return .run { _ in finished.withValue { $0 += 1 } }
          }
        }
      }
      let task = store.send(.start)

      func sendChildren(_ count: Int) async throws {
        let target = finished.value + count
        for _ in 0..<count { sendChild.yield() }
        while finished.value < target { try await Task.sleep(nanoseconds: 1_000_000) }
      }

      try await sendChildren(1_000)
      let before = await settledMallocBytesInUse()
      try await sendChildren(10_000)
      let after = await settledMallocBytesInUse()
      sendChild.finish()
      await task.finish()

      // Retaining every finished child task grows the heap by over a kilobyte per child (about
      // 13 MB here). Releasing them leaves nothing per child behind.
      XCTAssertLessThan(after - before, 3_000_000, "Heap grew by \(after - before) bytes")
    }
  #endif
}

#if canImport(Darwin)
  @MainActor
  private func settledMallocBytesInUse() async -> Int {
    var previous = mallocBytesInUse()
    for _ in 0..<40 {
      try? await Task.sleep(nanoseconds: 50_000_000)
      let current = mallocBytesInUse()
      if abs(current - previous) < 64 * 1024 { return current }
      previous = current
    }
    return previous
  }

  private func mallocBytesInUse() -> Int {
    var statistics = malloc_statistics_t()
    malloc_zone_statistics(nil, &statistics)
    return statistics.size_in_use
  }
#endif
