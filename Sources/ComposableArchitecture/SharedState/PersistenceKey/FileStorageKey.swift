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
  // TODO: Should this be a struct wrapped around a class?

  /// A type defining a file persistence strategy
  ///
  /// Use ``PersistenceKey/fileStorage(_:)`` to create values of this type.
  public final class FileStorageKey<Value: Codable & Sendable>: PersistenceKey, @unchecked Sendable
  {
    @Dependency(\.defaultFileStorage) fileprivate var queue
    let url: URL
    var workItem: DispatchWorkItem?
    var notificationListener: Any!

    init(url: URL) {
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
          self.queue.async(execute: workItem)
          self.queue.async(
            execute: DispatchWorkItem {
              self.workItem?.cancel()
              self.workItem = nil
            })
        }
      #endif
    }

    deinit {
      NotificationCenter.default.removeObserver(self.notificationListener!)
    }

    public func load() -> Value? {
      try? JSONDecoder().decode(Value.self, from: self.queue.load(from: self.url))
    }

    public func save(_ value: Value) {
      self.workItem?.cancel()
      let workItem = DispatchWorkItem { [weak self] in
        guard let self else { return }
        self.queue.setIsSetting(true)
        try? self.queue.save(JSONEncoder().encode(value), to: self.url)
        self.workItem = nil
      }
      self.workItem = workItem
      if canListenForResignActive {
        // TODO: Configurable debounce? Should this be shorter, at least in DEBUG/simulators?
        self.queue.asyncAfter(interval: .seconds(5), execute: workItem)
      } else {
        self.queue.async(execute: workItem)
      }
    }

    public var updates: AsyncStream<Value?> {
      AsyncStream { continuation in
        // NB: Make sure there is a file to create a source for.
        if !FileManager.default.fileExists(atPath: self.url.path) {
          try? FileManager.default
            .createDirectory(
              at: self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
          try? self.queue.save(Data(), to: self.url)
        }

        let cancellable = self.queue.fileSystemSource(
          url: self.url,
          eventMask: [.write, .delete, .rename]
        ) {
          // TODO: Do we need to do weak self?
          if self.queue.isSetting() == true {
            self.queue.setIsSetting(false)
          } else {
            continuation.yield(self.load())
          }
        }
        continuation.onTermination = { [cancellable = UncheckedSendable(cancellable)] _ in
          cancellable.wrappedValue.cancel()
        }
      }
    }
  }

  extension FileStorageKey: Hashable {
    public static func == (lhs: FileStorageKey, rhs: FileStorageKey) -> Bool {
      lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.url)
    }
  }

  /// A type that encapsulates saving and loading data from disk.
  public protocol FileStorage: Sendable {
    // TODO: replace these two async endpoints with an `AnyScheduler` property?
    func async(execute workItem: DispatchWorkItem)
    func asyncAfter(interval: DispatchTimeInterval, execute: DispatchWorkItem)
    func isSetting() -> Bool?
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
  /// This is the version of the ``Dependencies/DependencyValues/defaultFileStorage`` dependency that
  /// is used by default when running your app in the simulator or on device.
  public struct LiveFileStorage: FileStorage {
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

    public func isSetting() -> Bool? {
      // TODO: Does this actually need to be a specific and be in the protocol, or could
      //      FileStorageKey just hold onto this state?
      self.queue.getSpecific(key: Self.isSettingKey)
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
  public final class MockFileStorage: FileStorage, Sendable {
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

    public func isSetting() -> Bool? {
      self._isSetting.value
    }

    public func async(execute workItem: DispatchWorkItem) {
      self.scheduler.schedule(workItem.perform)
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
      MockFileStorage()
    }
    static var testValue: any FileStorage {
      MockFileStorage()
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
