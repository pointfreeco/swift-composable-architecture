import Combine
import Dependencies
import Foundation

extension PersistenceReaderKey {
  /// Creates a persistence key that can read and write to a `Codable` value in the file system.
  ///
  /// - Parameters:
  ///   - url: The file URL from which to read and write the value.
  ///   - decoder: The JSONDecoder to use for decoding the value.
  ///   - encoder: The JSONEncoder to use for encoding the value.
  /// - Returns: A file persistence key.
  public static func fileStorage<Value: Codable>(
    _ url: URL,
    decoder: JSONDecoder = JSONDecoder(),
    encoder: JSONEncoder = JSONEncoder()
  ) -> Self
  where Self == FileStorageKey<Value> {
    FileStorageKey(
      url: url,
      decode: { try decoder.decode(Value.self, from: $0) },
      encode: { try encoder.encode($0) }
    )
  }

  /// Creates a persistence key that can read and write to a value in the file system.
  ///
  /// - Parameters:
  ///   - url: The file URL from which to read and write the value.
  ///   - decode: The closure to use for decoding the value.
  ///   - encode: The closure to use for encoding the value.
  /// - Returns: A file persistence key.
  public static func fileStorage<Value>(
    _ url: URL,
    decode: @escaping @Sendable (Data) throws -> Value,
    encode: @escaping @Sendable (Value) throws -> Data
  ) -> Self
  where Self == FileStorageKey<Value> {
    FileStorageKey(url: url, decode: decode, encode: encode)
  }
}

/// A type defining a file persistence strategy
///
/// Use ``PersistenceReaderKey/fileStorage(_:decoder:encoder:)`` to create values of this type.
public final class FileStorageKey<Value: Sendable>: PersistenceKey, Sendable {
  private let storage: FileStorage
  private let isSetting = LockIsolated(false)
  private let url: URL
  private let decode: @Sendable (Data) throws -> Value
  private let encode: @Sendable (Value) throws -> Data
  fileprivate let state = LockIsolated(State())

  fileprivate struct State {
    var value: Value?
    var workItem: DispatchWorkItem?
  }

  public var id: AnyHashable {
    FileStorageKeyID(url: self.url, storage: self.storage)
  }

  fileprivate init(
    url: URL,
    decode: @escaping @Sendable (Data) throws -> Value,
    encode: @escaping @Sendable (Value) throws -> Data
  ) {
    @Dependency(\.defaultFileStorage) var storage
    self.storage = storage
    self.url = url
    self.decode = decode
    self.encode = encode
  }

  public func load(initialValue: Value?) -> Value? {
    do {
      return try decode(self.storage.load(self.url))
    } catch {
      return initialValue
    }
  }

  public func save(_ value: Value) {
    self.state.withValue { state in
      if state.workItem == nil {
        self.isSetting.setValue(true)
        try? self.storage.save(encode(value), self.url)
        let workItem = DispatchWorkItem { [weak self] in
          guard let self else { return }
          self.state.withValue { state in
            defer {
              state.value = nil
              state.workItem = nil
            }
            guard let value = state.value
            else { return }
            self.isSetting.setValue(true)
            try? self.storage.save(self.encode(value), self.url)
          }
        }
        state.workItem = workItem
        if canListenForResignActive {
          self.storage.asyncAfter(.seconds(1), workItem)
        } else {
          self.storage.async(workItem)
        }
      } else {
        state.value = value
      }
    }
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @escaping @Sendable (_ newValue: Value?) -> Void
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
          self.state.withValue { state in
            if self.isSetting.value == true {
              self.isSetting.setValue(false)
            } else {
              state.workItem?.cancel()
              state.workItem = nil
              didSet(self.load(initialValue: initialValue))
            }
          }
        }
        let deleteCancellable = self.storage.fileSystemSource(self.url, [.delete, .rename]) {
          self.state.withValue { state in
            state.workItem?.cancel()
            state.workItem = nil
          }
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
    self.state.withValue { state in
      guard let workItem = state.workItem
      else { return }
      self.storage.async(workItem)
      self.storage.async(
        DispatchWorkItem {
          self.state.withValue { state in
            state.workItem?.cancel()
            state.workItem = nil
          }
        }
      )
    }
  }
}

private struct FileStorageKeyID: Hashable {
  let url: URL
  let storage: FileStorage
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
  /// Default file storage used by ``PersistenceReaderKey/fileStorage(_:decoder:encoder:)``.
  ///
  /// Use this dependency to override the manner in which ``PersistenceReaderKey/fileStorage(_:decoder:encoder:)``
  /// interacts with file storage. For example, while your app is running for UI tests you
  /// probably do not want your features writing changes to disk, which would cause that data to
  /// bleed over from test to test.
  ///
  /// So, for that situation you can use the ``FileStorage/inMemory`` file storage so that each
  /// run of the app starts with a fresh "file system" that will never interfere with other tests:
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
public struct FileStorage: Hashable, Sendable {
  let id: AnyHashableSendable
  let async: @Sendable (DispatchWorkItem) -> Void
  let asyncAfter: @Sendable (DispatchTimeInterval, DispatchWorkItem) -> Void
  let createDirectory: @Sendable (URL, Bool) throws -> Void
  let fileExists: @Sendable (URL) -> Bool
  let fileSystemSource:
    @Sendable (URL, DispatchSource.FileSystemEvent, @escaping @Sendable () -> Void) ->
      AnyCancellable
  let load: @Sendable (URL) throws -> Data
  @_spi(Internals) public let save: @Sendable (Data, URL) throws -> Void

  /// File storage that interacts directly with the file system for saving, loading and listening
  /// for file changes.
  ///
  /// This is the version of the ``Dependencies/DependencyValues/defaultFileStorage`` dependency
  /// that is used by default when running your app in the simulator or on device.
  public static let fileSystem = fileSystem(
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
      fileSystemSource: { url, event, handler in
        guard event.contains(.write)
        else { return AnyCancellable {} }
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

  fileprivate struct Handler: Hashable, Sendable {
    let id = UUID()
    let operation: @Sendable () -> Void
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
      hasher.combine(self.id)
    }
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}
