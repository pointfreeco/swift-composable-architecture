#if canImport(Perception)
  import Combine
  import Foundation

  #if canImport(AppKit)
    import AppKit
  #endif
  #if canImport(UIKit)
    import UIKit
  #endif
  #if canImport(WatchKit)
    import WatchKit
  #endif

  extension PersistenceKey {
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
  /// Use ``PersistenceKey/fileStorage(_:)`` to create values of this type.
  public final class FileStorageKey<Value: Codable & Sendable>: PersistenceKey, @unchecked Sendable
  {
    let storage: any FileStorage
    let url: URL
    let value = LockIsolated<Value?>(nil)
    var workItem: DispatchWorkItem?
    var notificationListener: Any!

    public init(url: URL) {
      @Dependency(\.defaultFileStorage) var storage
      self.storage = storage
      self.url = url
      #if canImport(AppKit) || canImport(UIKit)
        self.notificationListener = NotificationCenter.default.addObserver(
          forName: willResignNotificationName,
          object: nil,
          queue: nil
        ) { [weak self] _ in
          guard
            let self,
            let workItem = self.workItem
          else { return }
          self.storage.async(execute: workItem)
          self.storage.async(
            execute: DispatchWorkItem {
              self.workItem?.cancel()
              self.workItem = nil
            }
          )
        }
      #endif
    }

    deinit {
      NotificationCenter.default.removeObserver(self.notificationListener!)
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
          self.storage.asyncAfter(interval: .seconds(5), execute: workItem)
        } else {
          self.storage.async(execute: workItem)
        }
      }
    }

    public func subscribe(
      initialValue: Value?, didSet: @escaping (_ newValue: Value?) -> Void
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
          didSet(self.load(initialValue: initialValue))
        }
      }
      return Shared.Subscription {
        cancellable.cancel()
      }
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

  // TODO: hide this thing from the public
  /// A type that encapsulates saving and loading data from disk.
  public protocol FileStorage: Sendable, AnyObject {
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

  /// A ``FileStorage`` conformance that interacts directly with the file system for saving, loading
  /// and listening for file changes.
  ///
  /// This is the version of the ``Dependencies/DependencyValues/defaultFileStorage`` dependency 
  /// that is used by default when running your app in the simulator or on device.
  final public class LiveFileStorage: FileStorage {
    private let queue: DispatchQueue
    public init(queue: DispatchQueue) {
      self.queue = queue
    }

    private static let isSettingKey = DispatchSpecificKey<Bool>()

    public func async(execute workItem: DispatchWorkItem) {
      self.queue.async(execute: workItem)
    }

    public func asyncAfter(interval: DispatchTimeInterval, execute workItem: DispatchWorkItem) {
      self.queue.asyncAfter(deadline: .now() + interval, execute: workItem)
    }

    public func createDirectory(
      at url: URL,
      withIntermediateDirectories createIntermediates: Bool
    ) throws {
      try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: createIntermediates
      )
    }

    public func isSetting() -> Bool? {
      // TODO: Does this actually need to be a specific and be in the protocol, or could
      //      FileStorageKey just hold onto this state?
      self.queue.getSpecific(key: Self.isSettingKey)
    }

    public func fileExists(at url: URL) -> Bool {
      FileManager.default.fileExists(atPath: url.path)
    }

    public func fileSystemSource(
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

    public func load(from url: URL) throws -> Data {
      try Data(contentsOf: url)
    }

    public func save(_ data: Data, to url: URL) throws {
      try FileManager.default
        .createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url)
    }

    public func setIsSetting(_ isSetting: Bool) {
      self.queue.setSpecific(key: Self.isSettingKey, value: isSetting)
    }
  }

  /// A ``FileStorage`` conformance that emulates a file system without actually writing anything
  /// to disk.
  ///
  /// This is the version of the ``Dependencies/DependencyValues/defaultFileStorage`` dependency that
  /// is used by default when running your app in tests and previews.
  public final class EphemeralFileStorage: FileStorage, Sendable {
    private let _isSetting = LockIsolated<Bool?>(nil)
    public let fileSystem = LockIsolated<[URL: Data]>([:])
    private let scheduler: AnySchedulerOf<DispatchQueue>
    private let sourceHandlers = LockIsolated<[URL: (() -> Void)]>([:])

    public init(scheduler: AnySchedulerOf<DispatchQueue> = .immediate) {
      self.scheduler = scheduler
    }

    public func asyncAfter(interval: DispatchTimeInterval, execute workItem: DispatchWorkItem) {
      self.scheduler.schedule(after: self.scheduler.now.advanced(by: .init(interval))) {
        workItem.perform()
      }
    }

    public func async(execute workItem: DispatchWorkItem) {
      self.scheduler.schedule(workItem.perform)
    }

    public func createDirectory(
      at url: URL,
      withIntermediateDirectories createIntermediates: Bool
    ) throws {}

    public func isSetting() -> Bool? {
      self._isSetting.value
    }

    public func fileExists(at url: URL) -> Bool {
      self.fileSystem.keys.contains(url)
    }

    public func fileSystemSource(
      url: URL,
      eventMask: DispatchSource.FileSystemEvent,
      handler: @escaping () -> Void
    ) -> AnyCancellable {
      self.sourceHandlers.withValue { $0[url] = handler }
      return AnyCancellable {
        self.sourceHandlers.withValue { $0[url] = nil }
      }
    }

    public func load(from url: URL) throws -> Data {
      guard let data = self.fileSystem[url]
      else {
        struct LoadError: Error {}
        throw LoadError()
      }
      return data
    }

    public func save(_ data: Data, to url: URL) throws {
      self.fileSystem.withValue { $0[url] = data }
      self.sourceHandlers.value[url]?()
    }

    public func setIsSetting(_ isSetting: Bool) {
      self._isSetting.setValue(isSetting)
    }
  }

  private enum FileStorageQueueKey: DependencyKey {
    static var liveValue: any FileStorage {
      LiveFileStorage(
        queue: DispatchQueue(label: "co.pointfree.ComposableArchitecture.FileStorage"))
    }
    static var previewValue: any FileStorage {
      EphemeralFileStorage()
    }
    static var testValue: any FileStorage {
      EphemeralFileStorage()
    }
  }

  extension DependencyValues {
    public var defaultFileStorage: any FileStorage {
      get { self[FileStorageQueueKey.self] }
      set { self[FileStorageQueueKey.self] = newValue }
    }
  }

  @_spi(Internals)
  public var willResignNotificationName: Notification.Name? {
    #if os(iOS) || os(tvOS) || os(visionOS)
      return UIApplication.willResignActiveNotification
    #elseif os(macOS)
      return NSApplication.willResignActiveNotification
    #else
      if #available(watchOS 7, *) {
        return WKExtension.applicationWillResignActiveNotification
      } else {
        return nil
      }
    #endif
  }

  private var canListenForResignActive: Bool {
    willResignNotificationName != nil
  }
#endif
