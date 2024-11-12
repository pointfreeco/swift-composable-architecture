@_spi(Internals) import ComposableArchitecture
import Perception
import XCTest

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
final class FileStorageTests: XCTestCase {
  func testBasics() throws {
    let fileSystem = LockIsolated<[URL: Data]>([:])
    try withDependencies {
      $0.defaultFileStorage = .inMemory(fileSystem: fileSystem, scheduler: .immediate)
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      expectNoDifference(fileSystem.value, [.fileURL: Data()])
      users.append(.blob)
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])
    }
  }

  func testBasics_CustomDecodeEncodeClosures() {
    let fileSystem = LockIsolated<[URL: Data]>([:])
    withDependencies {
      $0.defaultFileStorage = .inMemory(fileSystem: fileSystem, scheduler: .immediate)
    } operation: {
      @Shared(.utf8String) var string = ""
      expectNoDifference(fileSystem.value, [.utf8StringURL: Data()])
      string = "hello"
      expectNoDifference(
        fileSystem.value[.utf8StringURL].map { String(decoding: $0, as: UTF8.self) },
        "hello"
      )
    }
  }

  func testThrottle() throws {
    let fileSystem = LockIsolated<[URL: Data]>([:])
    let testScheduler = DispatchQueue.test
    try withDependencies {
      $0.defaultFileStorage = .inMemory(
        fileSystem: fileSystem,
        scheduler: testScheduler.eraseToAnyScheduler()
      )
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      try expectNoDifference(fileSystem.value.users(for: .fileURL), nil)

      users.append(.blob)
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      users.append(.blobJr)
      testScheduler.advance(by: .seconds(1) - .milliseconds(1))
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      users.append(.blobSr)
      testScheduler.advance(by: .milliseconds(1))
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob, .blobJr, .blobSr])

      testScheduler.advance(by: .seconds(1))
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob, .blobJr, .blobSr])

      testScheduler.advance(by: .seconds(0.5))
      users.append(.blobEsq)
      try expectNoDifference(
        fileSystem.value.users(for: .fileURL),
        [
          .blob,
          .blobJr,
          .blobSr,
          .blobEsq,
        ]
      )
    }
  }

  func testNoThrottling() throws {
    let fileSystem = LockIsolated<[URL: Data]>([:])
    let testScheduler = DispatchQueue.test
    try withDependencies {
      $0.defaultFileStorage = .inMemory(
        fileSystem: fileSystem,
        scheduler: testScheduler.eraseToAnyScheduler()
      )
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      try expectNoDifference(fileSystem.value.users(for: .fileURL), nil)

      users.append(.blob)
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      testScheduler.advance(by: .seconds(2))
      users.append(.blobJr)
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob, .blobJr])
    }
  }

  func testWillResign() throws {
    guard let willResignNotificationName else { return }

    let fileSystem = LockIsolated<[URL: Data]>([:])
    let testScheduler = DispatchQueue.test
    try withDependencies {
      $0.defaultFileStorage = .inMemory(
        fileSystem: fileSystem,
        scheduler: testScheduler.eraseToAnyScheduler()
      )
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      try expectNoDifference(fileSystem.value.users(for: .fileURL), nil)

      users.append(.blob)
      users.append(.blobJr)
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      NotificationCenter.default.post(name: willResignNotificationName, object: nil)
      testScheduler.advance()
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob, .blobJr])
    }
  }

  func testWillTerminate() throws {
    guard let willTerminateNotificationName else { return }

    let fileSystem = LockIsolated<[URL: Data]>([:])
    let testScheduler = DispatchQueue.test
    try withDependencies {
      $0.defaultFileStorage = .inMemory(
        fileSystem: fileSystem,
        scheduler: testScheduler.eraseToAnyScheduler()
      )
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      try expectNoDifference(fileSystem.value.users(for: .fileURL), nil)

      users.append(.blob)
      users.append(.blobJr)
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      NotificationCenter.default.post(name: willTerminateNotificationName, object: nil)
      testScheduler.advance()
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob, .blobJr])
    }
  }

  func testMultipleFiles() throws {
    let fileSystem = LockIsolated<[URL: Data]>([:])
    try withDependencies {
      $0.defaultFileStorage = .inMemory(fileSystem: fileSystem)
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      @Shared(.fileStorage(.anotherFileURL)) var otherUsers = [User]()

      users.append(.blob)
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])
      try expectNoDifference(fileSystem.value.users(for: .anotherFileURL), nil)

      otherUsers.append(.blobJr)
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])
      try expectNoDifference(fileSystem.value.users(for: .anotherFileURL), [.blobJr])
    }
  }

  func testLivePersistence() async throws {
    guard let willResignNotificationName else { return }
    try? FileManager.default.removeItem(at: .fileURL)

    try await withDependencies {
      $0.defaultFileStorage = .fileSystem
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()

      await $users.withLock { $0.append(.blob) }
      NotificationCenter.default
        .post(name: willResignNotificationName, object: nil)
      await Task.yield()

      try expectNoDifference(
        JSONDecoder().decode([User].self, from: Data(contentsOf: .fileURL)),
        [.blob]
      )
    }
  }

  func testInitialValue() async throws {
    try await withMainSerialExecutor {
      let fileSystem = try LockIsolated<[URL: Data]>(
        [.fileURL: try JSONEncoder().encode([User.blob])]
      )
      try await withDependencies {
        $0.defaultFileStorage = .inMemory(fileSystem: fileSystem)
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        _ = users
        await Task.yield()
        try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])
      }
    }
  }

  func testInitialValue_LivePersistence() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        _ = users
        await Task.yield()
        try expectNoDifference(
          JSONDecoder().decode([User].self, from: Data(contentsOf: .fileURL)),
          [.blob]
        )
      }
    }
  }

  func testWriteFile() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        await Task.yield()
        expectNoDifference(users, [.blob])

        try JSONEncoder().encode([User.blobJr]).write(to: .fileURL)
        try await Task.sleep(nanoseconds: 10_000_000)
        expectNoDifference(users, [.blobJr])
      }
    }
  }

  func testWriteFileWhileThrottling() throws {
    let fileSystem = LockIsolated<[URL: Data]>([:])
    let scheduler = DispatchQueue.test
    let fileStorage = FileStorage.inMemory(
      fileSystem: fileSystem,
      scheduler: scheduler.eraseToAnyScheduler()
    )

    try withDependencies {
      $0.defaultFileStorage = fileStorage
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()

      users.append(.blob)
      try expectNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      try fileStorage.save(Data(), .fileURL)
      scheduler.run()
      expectNoDifference(users, [.blob])
      try expectNoDifference(fileSystem.value.users(for: .fileURL), nil)
    }
  }

  func testDeleteFile() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        await Task.yield()
        expectNoDifference(users, [.blob])

        try FileManager.default.removeItem(at: .fileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        expectNoDifference(users, [])
      }
    }
  }

  func testMoveFile() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try? FileManager.default.removeItem(at: .anotherFileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        await Task.yield()
        expectNoDifference(users, [.blob])

        try FileManager.default.moveItem(at: .fileURL, to: .anotherFileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        expectNoDifference(users, [])

        try FileManager.default.removeItem(at: .fileURL)
        try FileManager.default.moveItem(at: .anotherFileURL, to: .fileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        expectNoDifference(users, [.blob])
      }
    }
  }

  func testDeleteFile_ThenWriteToFile() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        await Task.yield()
        expectNoDifference(users, [.blob])

        try FileManager.default.removeItem(at: .fileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        expectNoDifference(users, [])

        try JSONEncoder().encode([User.blobJr]).write(to: .fileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        expectNoDifference(users, [.blobJr])
      }
    }
  }

  func testMismatchTypes() {
    XCTAssertEqual(
      FileStorageKey<Int>.fileStorage(.fileURL).id,
      FileStorageKey<Bool>.fileStorage(.fileURL).id
    )
    XCTAssertNotEqual(
      FileStorageKey<Int>.fileStorage(.fileURL).id,
      FileStorageKey<Int>.fileStorage(.anotherFileURL).id
    )
    XCTAssertNotEqual(
      FileStorageKey<Int>.fileStorage(.fileURL).id,
      withDependencies {
        $0.defaultFileStorage = .fileSystem
      } operation: {
        FileStorageKey<Int>.fileStorage(.fileURL).id
      }
    )

    XCTAssertEqual(
      AppStorageKey<Int>.appStorage("key").id,
      AppStorageKey<Bool>.appStorage("key").id
    )
    XCTAssertNotEqual(
      AppStorageKey<Int>.appStorage("key").id,
      AppStorageKey<Int>.appStorage("key2").id
    )
    XCTAssertNotEqual(
      AppStorageKey<Int>.appStorage("key").id,
      withDependencies {
        $0.defaultAppStorage = UserDefaults(suiteName: "\(NSTemporaryDirectory())test-mismatch")!
      } operation: {
        AppStorageKey<Int>.appStorage("key").id
      }
    )

    XCTAssertEqual(
      InMemoryKey<Int>.inMemory("key").id,
      InMemoryKey<Bool>.inMemory("key").id
    )
    XCTAssertNotEqual(
      InMemoryKey<Int>.inMemory("key").id,
      InMemoryKey<Int>.inMemory("key2").id
    )
    XCTAssertNotEqual(
      InMemoryKey<Int>.inMemory("key").id,
      withDependencies {
        $0.defaultInMemoryStorage = InMemoryStorage()
      } operation: {
        InMemoryKey<Int>.inMemory("key").id
      }
    )
  }

  func testTwoInMemoryFileStorages() {
    let shared1 = withDependencies {
      $0.defaultFileStorage = .inMemory
    } operation: {
      @Shared(.fileStorage(.userURL)) var user = User(id: 1, name: "Blob")
      return $user
    }
    let shared2 = withDependencies {
      $0.defaultFileStorage = .inMemory
    } operation: {
      @Shared(.fileStorage(.userURL)) var user = User(id: 1, name: "Blob")
      return $user
    }

    shared1.wrappedValue.name = "Blob Jr"
    XCTAssertEqual(shared1.wrappedValue.name, "Blob Jr")
    XCTAssertEqual(shared2.wrappedValue.name, "Blob")
    shared2.wrappedValue.name = "Blob Sr"
    XCTAssertEqual(shared1.wrappedValue.name, "Blob Jr")
    XCTAssertEqual(shared2.wrappedValue.name, "Blob Sr")
  }

  func testCancelThrottleWhenFileIsDeleted() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User.blob]
        await Task.yield()
        expectNoDifference(users, [.blob])

        await $users.withLock { $0 = [.blobJr] }  // NB: Saved immediately
        await $users.withLock { $0 = [.blobSr] }  // NB: Throttled for 1 second
        try FileManager.default.removeItem(at: .fileURL)
        try await Task.sleep(nanoseconds: 1_200_000_000)
        expectNoDifference(users, [.blob])
        try XCTAssertEqual(Data(contentsOf: .fileURL), Data())
      }
    }
  }

  func testWritesFromManyThreads() async {
    let fileSystem = LockIsolated<[URL: Data]>([:])
    let fileStorage = FileStorage.inMemory(
      fileSystem: fileSystem,
      scheduler: DispatchQueue.main.eraseToAnyScheduler()
    )

    await withDependencies {
      $0.defaultFileStorage = fileStorage
    } operation: {
      @Shared(.fileStorage(.fileURL)) var count = 0
      let max = 10_000
      await withTaskGroup(of: Void.self) { group in
        for index in (1...max) {
          group.addTask { [count = $count] in
            try? await Task.sleep(for: .milliseconds(Int.random(in: 200...3_000)))
            await count.withLock { $0 += index }
          }
        }
      }

      XCTAssertEqual(count, max * (max + 1) / 2)
    }
  }

  @MainActor
  func testUpdateFileSystemFromBackgroundThread() async throws {
    await withDependencies {
      $0.defaultFileStorage = .fileSystem
    } operation: {
      try? FileManager.default.removeItem(at: .fileURL)

      @Shared(.fileStorage(.fileURL)) var count = 0

      let publisherExpectation = expectation(description: "publisher")
      let cancellable = $count.publisher.sink { _ in
        XCTAssertTrue(Thread.isMainThread)
        publisherExpectation.fulfill()
      }
      defer { _ = cancellable }

      await withUnsafeContinuation { continuation in
        DispatchQueue.global().async {
          XCTAssertFalse(Thread.isMainThread)
          try! Data("1".utf8).write(to: .fileURL)
          continuation.resume()
        }
      }

      await fulfillment(of: [publisherExpectation], timeout: 1)
    }
  }

  @MainActor
  func testMultipleMutations() async throws {
    try? FileManager.default.removeItem(
      at: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("counts.json")
    )

    try await withDependencies {
      $0.defaultFileStorage = .fileSystem
    } operation: {
      @Shared(.counts) var counts
      for m in 1...1000 {
        for n in 1...10 {
          $counts.withLock {
            $0[n, default: 0] += 1
          }
        }
        expectNoDifference(
          Dictionary((1...10).map { n in (n, m) }, uniquingKeysWith: { $1 }),
          counts
        )
        try await Task.sleep(for: .seconds(0.001))
      }
    }
  }

  func testMultipleMutationsFromMultipleThreads() async throws {
    try? FileManager.default.removeItem(
      at: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("counts.json")
    )

    await withDependencies {
      $0.defaultFileStorage = .fileSystem
    } operation: {
      @Shared(.counts) var counts

      await withTaskGroup(of: Void.self) { group in
        for _ in 1...1000 {
          group.addTask { [$counts] in
            for _ in 1...10 {
              await $counts.withLock { $0[0, default: 0] += 1 }
              try? await Task.sleep(for: .seconds(0.2))
            }
          }
        }
      }

      XCTAssertEqual(counts[0], 10_000)
    }
  }
}

extension PersistenceReaderKey
where Self == FileStorageKey<String> {
  fileprivate static var utf8String: Self {
    .fileStorage(
      .utf8StringURL,
      decode: { data in String(decoding: data, as: UTF8.self) },
      encode: { string in Data(string.utf8) }
    )
  }
}

extension URL {
  fileprivate static let fileURL = Self(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("file.json")
  fileprivate static let userURL = Self(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("user.json")
  fileprivate static let anotherFileURL = Self(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("another-file.json")
  fileprivate static let utf8StringURL = Self(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("utf8-string.json")
}

private struct User: Codable, Equatable, Identifiable {
  let id: Int
  var name: String
  static let blob = User(id: 1, name: "Blob")
  static let blobJr = User(id: 2, name: "Blob Jr.")
  static let blobSr = User(id: 3, name: "Blob Sr.")
  static let blobEsq = User(id: 4, name: "Blob Esq.")
}

extension [URL: Data] {
  fileprivate func users(for url: URL) throws -> [User]? {
    guard
      let data = self[url],
      !data.isEmpty
    else { return nil }
    return try JSONDecoder().decode([User].self, from: data)
  }
}

extension PersistenceKey where Self == PersistenceKeyDefault<FileStorageKey<[Int: Int]>> {
  fileprivate static var counts: Self {
    Self(
      .fileStorage(
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("counts.json")
      ),
      [:]
    )
  }
}
