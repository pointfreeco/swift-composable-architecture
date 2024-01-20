import Perception
@_spi(Internals) import ComposableArchitecture
import XCTest

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
final class FileStorageTests: XCTestCase {
  func testBasics() throws {
    let testQueue = TestPersistenceQueue(scheduler: .immediate)
    try withDependencies {
      $0._fileStoragePersistenceQueue = testQueue
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      XCTAssertEqual(testQueue.fileSystem.value, [:])
      users.append(.blob)
      try XCTAssertNoDifference(testQueue.fileSystem.value.users(for: .fileURL), [.blob])
    }
  }

  func testDebounce() throws {
    let testScheduler = DispatchQueue.test
    let testQueue = TestPersistenceQueue(scheduler: testScheduler.eraseToAnyScheduler())
    try withDependencies {
      $0._fileStoragePersistenceQueue = testQueue
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      users.append(.blob)
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      testScheduler.advance(by: .seconds(5) - .milliseconds(1))
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      testScheduler.advance(by: .milliseconds(1))
      try XCTAssertNoDifference(testQueue.fileSystem.value.users(for: .fileURL), [.blob])
    }
  }

  func testCancelInFlight() throws {
    let testScheduler = DispatchQueue.test
    let testQueue = TestPersistenceQueue(scheduler: testScheduler.eraseToAnyScheduler())
    try withDependencies {
      $0._fileStoragePersistenceQueue = testQueue
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      users.append(.blob)
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      testScheduler.advance(by: .seconds(3))
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      users.append(.blobJr)
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      testScheduler.advance(by: .seconds(3))
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      testScheduler.advance(by: .seconds(2))

      try XCTAssertNoDifference(testQueue.fileSystem.value.users(for: .fileURL), [.blob, .blobJr])
    }
  }

  func testWillResign() throws {
    let testScheduler = DispatchQueue.test
    let testQueue = TestPersistenceQueue(scheduler: testScheduler.eraseToAnyScheduler())
    try withDependencies {
      $0._fileStoragePersistenceQueue = testQueue
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      users.append(.blob)
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
      testScheduler.advance()
      try XCTAssertEqual(testQueue.fileSystem.value.users(for: .fileURL), [.blob])
    }
  }

  func testWillResignAndDebounce() throws {
    let testScheduler = DispatchQueue.test
    let testQueue = TestPersistenceQueue(scheduler: testScheduler.eraseToAnyScheduler())
    try withDependencies {
      $0._fileStoragePersistenceQueue = testQueue
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      users.append(.blob)
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      testScheduler.advance(by: .seconds(3))
      XCTAssertEqual(testQueue.fileSystem.value, [:])

      NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
      testScheduler.advance()
      try XCTAssertNoDifference(testQueue.fileSystem.value.users(for: .fileURL), [.blob])

      users.append(.blobJr)
      testScheduler.run()
      try XCTAssertNoDifference(testQueue.fileSystem.value.users(for: .fileURL), [.blob, .blobJr])
    }
  }

  func testMultipleFiles() throws {
    let testQueue = TestPersistenceQueue()
    try withDependencies {
      $0._fileStoragePersistenceQueue = testQueue
    } operation: {
      @Shared(.fileStorage(.fileURL)) var users = [User]()
      @Shared(.fileStorage(.anotherFileURL)) var otherUsers = [User]()

      users.append(.blob)
      try XCTAssertEqual(testQueue.fileSystem.value.users(for: .fileURL), [.blob])
      try XCTAssertEqual(testQueue.fileSystem.value.users(for: .anotherFileURL), nil)

      otherUsers.append(.blobJr)
      try XCTAssertEqual(testQueue.fileSystem.value.users(for: .fileURL), [.blob])
      try XCTAssertEqual(testQueue.fileSystem.value.users(for: .anotherFileURL), [.blobJr])
    }
  }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension URL {
  fileprivate static let fileURL = Self.temporaryDirectory.appending(component: "file.json")
  fileprivate static let anotherFileURL = Self.temporaryDirectory
    .appending(component: "another-file.json")
}

private struct User: Codable, Equatable {
  let id: Int
  let name: String
  static let blob = User(id: 1, name: "Blob")
  static let blobJr = User(id: 1, name: "Blob Jr.")
  static let blobSr = User(id: 1, name: "Blob Sr.")
}

extension [URL: Data] {
  fileprivate func users(for url: URL) throws -> [User]? {
    try self[url].map { try JSONDecoder().decode([User].self, from: $0) }
  }
}
