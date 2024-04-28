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

/// A type defining a file persistence strategy
///
/// Use ``PersistenceReaderKey/fileStorage(_:)`` to create values of this type.
public final class FileStorageKey<Value: Codable & Sendable>: PersistenceKey, Sendable {
  fileprivate let storage: FileStorage
  let isSetting = LockIsolated(false)
  let url: URL
  let value = LockIsolated<Value?>(nil)
  let workItem = LockIsolated<DispatchWorkItem?>(nil)

  public init(url: URL) {
    @Dependency(\.defaultFileStorage) var storage
    self.storage = storage
    self.url = url
  }

  public func load(initialValue: Value?) -> Value? {
    do {
      return try JSONDecoder().decode(Value.self, from: self.storage.load(self.url))
    } catch {
      return initialValue
    }
  }

  public func save(_ value: Value) {
    if self.workItem.value == nil {
      self.isSetting.setValue(true)
      try? self.storage.save(JSONEncoder().encode(value), self.url)
      let workItem = DispatchWorkItem { [weak self] in
        guard let self, let value = self.value.value else { return }
        self.isSetting.setValue(true)
        try? self.storage.save(JSONEncoder().encode(value), self.url)
        self.value.setValue(nil)
        self.workItem.setValue(nil)
      }
      self.workItem.setValue(workItem)
      if canListenForResignActive {
        self.storage.asyncAfter(.seconds(1), workItem)
      } else {
        self.storage.async(workItem)
      }
    } else {
      self.value.setValue(value)
    }
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @Sendable @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    let cancellable = LockIsolated<AnyCancellable?>(nil)
    @Sendable func setUpSources() {
      cancellable.withValue { [weak self] in
        $0?.cancel()
        guard let self else { return }
        // NB: Make sure there is a file to create a source for.
        if !self.storage.fileExists(self.url) {
          try? self.storage.createDirectory(self.url.deletingLastPathComponent(), true)
          try? self.storage.save(Data(), self.url)
        }
        let writeCancellable = self.storage.fileSystemSource(self.url, [.write]) {
          if self.isSetting.value == true {
            self.isSetting.setValue(false)
          } else {
            self.workItem.withValue {
              $0?.cancel()
              $0 = nil
            }
            didSet(self.load(initialValue: initialValue))
          }
        }
        let deleteCancellable = self.storage.fileSystemSource(self.url, [.delete, .rename]) {
          `didSet`(self.load(initialValue: initialValue))
          setUpSources()
        }
        $0 = AnyCancellable {
          writeCancellable.cancel()
          deleteCancellable.cancel()
        }
      }
    }
    setUpSources()
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
      cancellable.withValue { $0?.cancel() }
      if let willResign {
        NotificationCenter.default.removeObserver(willResign)
      }
      if let willTerminate {
        NotificationCenter.default.removeObserver(willTerminate)
      }
    }
  }

  private func performImmediately() {
    guard let workItem = self.workItem.value
    else { return }
    self.storage.async(workItem)
    self.storage.async(
      DispatchWorkItem {
        self.workItem.withValue {
          $0?.cancel()
          $0 = nil
        }
      }
    )
  }
}

extension FileStorageKey: Hashable {
  public static func == (lhs: FileStorageKey, rhs: FileStorageKey) -> Bool {
    lhs.url == rhs.url && lhs.storage.id == rhs.storage.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.url)
    hasher.combine(self.storage.id)
  }
}

private enum FileStorageDependencyKey: DependencyKey {
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
  /// Default file storage used by ``PersistenceReaderKey/fileStorage(_:)``.
  ///
  /// Use this dependency to override the manner in which ``PersistenceReaderKey/fileStorage(_:)``
  /// interacts with file storage. For example, while your app is running for UI tests you
  /// probably do not want your features writing changes to disk, which would cause that data to
  /// bleed over from test to test.
  ///
  /// So, for that situation you can use the ``FileStorage/inMemory`` file storage so that each
  /// run of the app starts with a fresh "file system" that will never interfer with other tests:
  ///
  /// ```swift
  /// @main
  /// struct EntryPoint: App {
  ///   let store = Store(initialState: AppFeature.State()) {
  ///     AppFeature()
  ///   } withDependencies: {
  ///     if ProcessInfo.processInfo.environment["UITesting"] == "true" {
  ///       $0.defaultFileStorage = .inMemory
  ///     }
  ///   }
  /// }
  /// ```
  public var defaultFileStorage: FileStorage {
    get { self[FileStorageDependencyKey.self] }
    set { self[FileStorageDependencyKey.self] = newValue }
  }
}

/// A type that encapsulates saving and loading data from disk.
public struct FileStorage: Sendable {
  let id: AnyHashableSendable
  let async: @Sendable (DispatchWorkItem) -> Void
  let asyncAfter: @Sendable (DispatchTimeInterval, DispatchWorkItem) -> Void
  let createDirectory: @Sendable (URL, Bool) throws -> Void
  let fileExists: @Sendable (URL) -> Bool
  let fileSystemSource:
    @Sendable (URL, DispatchSource.FileSystemEvent, @escaping () -> Void) -> AnyCancellable
  let load: @Sendable (URL) throws -> Data
  @_spi(Internals) public let save: @Sendable (Data, URL) throws -> Void

  /// File storage that interacts directly with the file system for saving, loading and listening
  /// for file changes.
  ///
  /// This is the version of the ``Dependencies/DependencyValues/defaultFileStorage`` dependency
  /// that is used by default when running your app in the simulator or on device.
  public static var fileSystem = fileSystem(
    queue: DispatchQueue(label: "co.pointfree.ComposableArchitecture.FileStorage")
  )

  /// File storage that emulates a file system without actually writing anything to disk.
  ///
  /// This is the version of the ``Dependencies/DependencyValues/defaultFileStorage`` dependency
  /// that is used by default when running your app in tests and previews.
  public static var inMemory: Self {
    inMemory(fileSystem: LockIsolated([:]))
  }

  @_spi(Internals) public static func fileSystem(queue: DispatchQueue) -> Self {
    Self(
      id: AnyHashableSendable(queue),
      async: { queue.async(execute: $0) },
      asyncAfter: { queue.asyncAfter(deadline: .now() + $0, execute: $1) },
      createDirectory: {
        try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: $1)
      },
      fileExists: { FileManager.default.fileExists(atPath: $0.path) },
      fileSystemSource: {
        let source = DispatchSource.makeFileSystemObjectSource(
          fileDescriptor: open($0.path, O_EVTONLY),
          eventMask: $1,
          queue: queue
        )
        source.setEventHandler(handler: $2)
        source.resume()
        return AnyCancellable {
          source.cancel()
          close(source.handle)
        }
      },
      load: { try Data(contentsOf: $0) },
      save: { try $0.write(to: $1) }
    )
  }

  @_spi(Internals) public static func inMemory(
    fileSystem: LockIsolated<[URL: Data]>,
    scheduler: AnySchedulerOf<DispatchQueue> = .immediate
  ) -> Self {
    let sourceHandlers = LockIsolated<[URL: Set<Handler>]>([:])
    return Self(
      id: AnyHashableSendable(ObjectIdentifier(fileSystem)),
      async: { scheduler.schedule($0.perform) },
      asyncAfter: { scheduler.schedule(after: scheduler.now.advanced(by: .init($0)), $1.perform) },
      createDirectory: { _, _ in },
      fileExists: { fileSystem.keys.contains($0) },
      fileSystemSource: { url, _, handler in
        let handler = Handler(operation: handler)
        sourceHandlers.withValue { _ = $0[url, default: []].insert(handler) }
        return AnyCancellable {
          sourceHandlers.withValue { _ = $0[url]?.remove(handler) }
        }
      },
      load: {
        guard let data = fileSystem[$0]
        else {
          struct LoadError: Error {}
          throw LoadError()
        }
        return data
      },
      save: { data, url in
        fileSystem.withValue { $0[url] = data }
        sourceHandlers.withValue { $0[url]?.forEach { $0.operation() } }
      }
    )
  }

  fileprivate struct Handler: Hashable {
    let id = UUID()
    let operation: () -> Void
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
      hasher.combine(self.id)
    }
  }
}
