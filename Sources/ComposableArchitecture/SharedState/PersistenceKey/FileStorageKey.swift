import Combine
import Dependencies
import Foundation

extension PersistenceReaderKey {
  /// Creates a persistence key that can read and write to a `Codable` value to the file system.
  ///
  /// - Parameter url: The file URL from which to read and write the value.
  /// - Returns: A file persistence key.
  public static func fileStorage<Value: Codable>(_ url: URL) -> Self
  where Self == FileStorageKey<Value> {
    FileStorageKey(url: url)
  }
}

// TODO: Audit unchecked sendable

/// A type defining a file persistence strategy
///
/// Use ``PersistenceReaderKey/fileStorage(_:)`` to create values of this type.
public final class FileStorageKey<Value: Codable & Sendable>: PersistenceKey, @unchecked Sendable {
  fileprivate let storage: any FileStorageProtocol
  let url: URL
  let value = LockIsolated<Value?>(nil)
  var workItem: DispatchWorkItem?

  public init(url: URL) {
    @Dependency(\.defaultFileStorage) var storage
    self.storage = storage.rawValue
    self.url = url
  }

  public func load(initialValue: Value?) -> Value? {
    do {
      return try JSONDecoder().decode(Value.self, from: self.storage.load(from: self.url))
    } catch {
      return initialValue
    }
  }

  public func save(_ value: Value) {
    self.value.setValue(value)
    if self.workItem == nil {
      let workItem = DispatchWorkItem { [weak self] in
        guard let self, let value = self.value.value else { return }
        self.storage.setIsSetting(true)
        try? self.storage.save(JSONEncoder().encode(value), to: self.url)
        self.value.setValue(nil)
        self.workItem = nil
      }
      self.workItem = workItem
      if canListenForResignActive {
        self.storage.asyncAfter(interval: .seconds(1), execute: workItem)
      } else {
        self.storage.async(execute: workItem)
      }
    }
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @Sendable @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    // NB: Make sure there is a file to create a source for.
    if !self.storage.fileExists(at: self.url) {
      try? self.storage
        .createDirectory(
          at: self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try? self.storage.save(Data(), to: self.url)
    }
    // TODO: detect deletion separately and restart source
    let cancellable = self.storage.fileSystemSource(
      url: self.url,
      eventMask: [.write, .delete, .rename]
    ) {
      if self.storage.isSetting() == true {
        self.storage.setIsSetting(false)
      } else {
        self.workItem?.cancel()
        self.workItem = nil
        didSet(self.load(initialValue: initialValue))
      }
    }
    let willResign: (any NSObjectProtocol)?
    if let willResignNotificationName {
      willResign = NotificationCenter.default.addObserver(
        forName: willResignNotificationName,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        guard let self
        else { return }
        self.performImmediately()
      }
    } else {
      willResign = nil
    }
    let willTerminate: (any NSObjectProtocol)?
    if let willTerminateNotificationName {
      willTerminate = NotificationCenter.default.addObserver(
        forName: willTerminateNotificationName,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        guard let self
        else { return }
        self.performImmediately()
      }
    } else {
      willTerminate = nil
    }
    return Shared.Subscription {
      cancellable.cancel()
      if let willResign {
        NotificationCenter.default.removeObserver(willResign)
      }
      if let willTerminate {
        NotificationCenter.default.removeObserver(willTerminate)
      }
    }
  }

  private func performImmediately() {
    guard let workItem = self.workItem
    else { return }
    self.storage.async(execute: workItem)
    self.storage.async(
      execute: DispatchWorkItem {
        self.workItem?.cancel()
        self.workItem = nil
      }
    )
  }
}

extension FileStorageKey: Hashable {
  public static func == (lhs: FileStorageKey, rhs: FileStorageKey) -> Bool {
    lhs.url == rhs.url && lhs.storage === rhs.storage
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.url)
    hasher.combine(ObjectIdentifier(self.storage))
  }
}

/// A type that encapsulates saving and loading data from disk.
public struct FileStorage {
  @_spi(Internals) public let rawValue: any FileStorageProtocol

  @_spi(Internals) public init(rawValue: some FileStorageProtocol) {
    self.rawValue = rawValue
  }

  /// File storage that interacts directly with the file system for saving, loading and listening
  /// for file changes.
  ///
  /// This is the version of the ``Dependencies/DependencyValues/defaultFileStorage`` dependency
  /// that is used by default when running your app in the simulator or on device.
  public static var fileSystem: Self {
    Self(
      rawValue: LiveFileStorage(
        queue: DispatchQueue(label: "co.pointfree.ComposableArchitecture.FileStorage")
      )
    )
  }

  /// File storage that emulates a file system without actually writing anything to disk.
  ///
  /// This is the version of the ``Dependencies/DependencyValues/defaultFileStorage`` dependency
  /// that is used by default when running your app in tests and previews.
  public static var inMemory: Self {
    Self(rawValue: InMemoryFileStorage())
  }
}

private enum FileStorageQueueKey: DependencyKey {
  static var liveValue: FileStorage {
    .fileSystem
  }
  static var previewValue: FileStorage {
    .inMemory
  }
  static var testValue: FileStorage {
    .inMemory
  }
}

extension DependencyValues {
  /// File storage used by ``PersistenceReaderKey/fileStorage(_:)``.
  public var defaultFileStorage: FileStorage {
    get { self[FileStorageQueueKey.self] }
    set { self[FileStorageQueueKey.self] = newValue }
  }
}

@_spi(Internals) public protocol FileStorageProtocol: Sendable, AnyObject {
  func async(execute workItem: DispatchWorkItem)
  func asyncAfter(interval: DispatchTimeInterval, execute: DispatchWorkItem)
  func createDirectory(
    at url: URL,
    withIntermediateDirectories createIntermediates: Bool
  ) throws
  func isSetting() -> Bool?
  func fileExists(at url: URL) -> Bool
  func fileSystemSource(
    url: URL,
    eventMask: DispatchSource.FileSystemEvent,
    handler: @escaping () -> Void
  ) -> AnyCancellable
  func load(from url: URL) throws -> Data
  func save(_ data: Data, to url: URL) throws
  func setIsSetting(_ isSetting: Bool)
}

@_spi(Internals) public final class LiveFileStorage: FileStorageProtocol {
  private let queue: DispatchQueue
  @_spi(Internals) public init(queue: DispatchQueue) {
    self.queue = queue
  }

  private static let isSettingKey = DispatchSpecificKey<Bool>()

  @_spi(Internals) public func async(execute workItem: DispatchWorkItem) {
    self.queue.async(execute: workItem)
  }

  @_spi(Internals) public func asyncAfter(
    interval: DispatchTimeInterval,
    execute workItem: DispatchWorkItem
  ) {
    self.queue.asyncAfter(deadline: .now() + interval, execute: workItem)
  }

  @_spi(Internals) public func createDirectory(
    at url: URL,
    withIntermediateDirectories createIntermediates: Bool
  ) throws {
    try FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: createIntermediates
    )
  }

  @_spi(Internals) public func isSetting() -> Bool? {
    // TODO: Does this actually need to be a specific and be in the protocol, or could
    //      FileStorageKey just hold onto this state?
    self.queue.getSpecific(key: Self.isSettingKey)
  }

  @_spi(Internals) public func fileExists(at url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }

  @_spi(Internals) public func fileSystemSource(
    url: URL,
    eventMask: DispatchSource.FileSystemEvent,
    handler: @escaping () -> Void
  ) -> AnyCancellable {
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: open(url.path, O_EVTONLY),
      eventMask: eventMask,
      queue: self.queue
    )
    source.setEventHandler(handler: handler)
    source.resume()
    return AnyCancellable {
      source.cancel()
      close(source.handle)
    }
  }

  @_spi(Internals) public func load(from url: URL) throws -> Data {
    try Data(contentsOf: url)
  }

  @_spi(Internals) public func save(_ data: Data, to url: URL) throws {
    try FileManager.default
      .createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
  }

  @_spi(Internals) public func setIsSetting(_ isSetting: Bool) {
    self.queue.setSpecific(key: Self.isSettingKey, value: isSetting)
  }
}

@_spi(Internals) public final class InMemoryFileStorage: FileStorageProtocol, Sendable {
  private let _isSetting = LockIsolated<Bool?>(nil)
  @_spi(Internals) public let fileSystem = LockIsolated<[URL: Data]>([:])
  private let scheduler: AnySchedulerOf<DispatchQueue>
  private let sourceHandlers = LockIsolated<[URL: (() -> Void)]>([:])

  @_spi(Internals) public init(scheduler: AnySchedulerOf<DispatchQueue> = .immediate) {
    self.scheduler = scheduler
  }

  @_spi(Internals) public func asyncAfter(interval: DispatchTimeInterval, execute workItem: DispatchWorkItem) {
    self.scheduler.schedule(after: self.scheduler.now.advanced(by: .init(interval))) {
      workItem.perform()
    }
  }

  @_spi(Internals) public func async(execute workItem: DispatchWorkItem) {
    self.scheduler.schedule(workItem.perform)
  }

  @_spi(Internals) public func createDirectory(
    at url: URL,
    withIntermediateDirectories createIntermediates: Bool
  ) throws {}

  @_spi(Internals) public func isSetting() -> Bool? {
    self._isSetting.value
  }

  @_spi(Internals) public func fileExists(at url: URL) -> Bool {
    self.fileSystem.keys.contains(url)
  }

  @_spi(Internals) public func fileSystemSource(
    url: URL,
    eventMask: DispatchSource.FileSystemEvent,
    handler: @escaping () -> Void
  ) -> AnyCancellable {
    self.sourceHandlers.withValue { $0[url] = handler }
    return AnyCancellable {
      self.sourceHandlers.withValue { $0[url] = nil }
    }
  }

  @_spi(Internals) public func load(from url: URL) throws -> Data {
    guard let data = self.fileSystem[url]
    else {
      struct LoadError: Error {}
      throw LoadError()
    }
    return data
  }

  @_spi(Internals) public func save(_ data: Data, to url: URL) throws {
    self.fileSystem.withValue { $0[url] = data }
    self.sourceHandlers.value[url]?()
  }

  @_spi(Internals) public func setIsSetting(_ isSetting: Bool) {
    self._isSetting.setValue(isSetting)
  }
}
