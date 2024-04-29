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
      XCTAssertNoDifference(fileSystem.value, [.fileURL: Data()])
      users.append(.blob)
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob])
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
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), nil)

      users.append(.blob)
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      users.append(.blobJr)
      testScheduler.advance(by: .seconds(1) - .milliseconds(1))
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      users.append(.blobSr)
      testScheduler.advance(by: .milliseconds(1))
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob, .blobJr, .blobSr])

      testScheduler.advance(by: .seconds(1))
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob, .blobJr, .blobSr])

      testScheduler.advance(by: .seconds(0.5))
      users.append(.blobEsq)
      try XCTAssertNoDifference(
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
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), nil)

      users.append(.blob)
      users.append(.blobJr)
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      NotificationCenter.default.post(name: willResignNotificationName, object: nil)
      testScheduler.advance()
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob, .blobJr])
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
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), nil)

      users.append(.blob)
      users.append(.blobJr)
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob])

      NotificationCenter.default.post(name: willTerminateNotificationName, object: nil)
      testScheduler.advance()
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob, .blobJr])
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
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob])
      try XCTAssertNoDifference(fileSystem.value.users(for: .anotherFileURL), nil)

      otherUsers.append(.blobJr)
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob])
      try XCTAssertNoDifference(fileSystem.value.users(for: .anotherFileURL), [.blobJr])
    }
  }

  @MainActor
  func testLivePersistence() async throws {
    guard let willResignNotificationName else { return }
    try? FileManager.default.removeItem(at: .fileURL)

    try await withDependencies {
      $0.defaultFileStorage = .fileSystem(queue: .main)
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()

      users.append(.blob)
      NotificationCenter.default
        .post(name: willResignNotificationName, object: nil)
      await Task.yield()

      try XCTAssertNoDifference(
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
        try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), [.blob])
      }
    }
  }

  func testInitialValue_LivePersistence() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem(queue: .main)
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        _ = users
        await Task.yield()
        try XCTAssertNoDifference(
          JSONDecoder().decode([User].self, from: Data(contentsOf: .fileURL)),
          [.blob]
        )
      }
    }
  }

  @MainActor
  func testWriteFile() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem(queue: .main)
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        await Task.yield()
        XCTAssertNoDifference(users, [.blob])

        try JSONEncoder().encode([User.blobJr]).write(to: .fileURL)
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertNoDifference(users, [.blobJr])
      }
    }
  }

  @MainActor
  func testWriteFileWhileDebouncing() throws {
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
      try fileStorage.save(Data(), .fileURL)
      scheduler.run()
      XCTAssertNoDifference(users, [])
      try XCTAssertNoDifference(fileSystem.value.users(for: .fileURL), nil)
    }
  }

  @MainActor
  func testDeleteFile() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem(queue: .main)
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        await Task.yield()
        XCTAssertNoDifference(users, [.blob])

        try FileManager.default.removeItem(at: .fileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertNoDifference(users, [])
      }
    }
  }

  @MainActor
  func testMoveFile() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try? FileManager.default.removeItem(at: .anotherFileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem(queue: .main)
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        await Task.yield()
        XCTAssertNoDifference(users, [.blob])

        try FileManager.default.moveItem(at: .fileURL, to: .anotherFileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertNoDifference(users, [])

        try FileManager.default.removeItem(at: .fileURL)
        try FileManager.default.moveItem(at: .anotherFileURL, to: .fileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertNoDifference(users, [.blob])
      }
    }
  }

  @MainActor
  func testDeleteFile_ThenWriteToFile() async throws {
    try await withMainSerialExecutor {
      try? FileManager.default.removeItem(at: .fileURL)
      try JSONEncoder().encode([User.blob]).write(to: .fileURL)

      try await withDependencies {
        $0.defaultFileStorage = .fileSystem(queue: .main)
      } operation: {
        @Shared(.fileStorage(.fileURL)) var users = [User]()
        await Task.yield()
        XCTAssertNoDifference(users, [.blob])

        try FileManager.default.removeItem(at: .fileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertNoDifference(users, [])

        try JSONEncoder().encode([User.blobJr]).write(to: .fileURL)
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertNoDifference(users, [.blobJr])
      }
    }
  }

  func testMismatchTypesSameCodability() {
    @Shared(.fileStorage(.fileURL)) var users: [User] = []
    @Shared(.fileStorage(.fileURL)) var users1: [User] = []
    @Shared(.fileStorage(.fileURL)) var users2: IdentifiedArrayOf<User> = []

    users.append(User(id: 1, name: "Blob"))
    XCTAssertEqual(users, [User(id: 1, name: "Blob")])
    XCTAssertEqual(users1, [User(id: 1, name: "Blob")])
    XCTAssertEqual(users2, [User(id: 1, name: "Blob")])
  }

  func testMismatchTypesDifferentCodability() {
    @Shared(.fileStorage(.fileURL)) var users: [User] = []
    @Shared(.fileStorage(.fileURL)) var users1: [User] = []
    @Shared(.fileStorage(.fileURL)) var users2 = false

    users.append(User(id: 1, name: "Blob"))
    XCTAssertEqual(users, [User(id: 1, name: "Blob")])
    XCTAssertEqual(users1, [User(id: 1, name: "Blob")])
    XCTAssertEqual(users2, false)

    users2 = true
    XCTAssertEqual(users, [])
    XCTAssertEqual(users1, [])
    XCTAssertEqual(users2, true)
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
}

extension URL {
  fileprivate static let fileURL = Self(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("file.json")
  fileprivate static let userURL = Self(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("user.json")
  fileprivate static let anotherFileURL = Self(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("another-file.json")
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
