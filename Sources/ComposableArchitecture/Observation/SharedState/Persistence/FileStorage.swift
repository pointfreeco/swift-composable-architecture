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

extension Persistent {
  public static func fileStorage<Value: Codable>(_ url: URL) -> Self
  where Self == _FileStorage<Value> {
    _FileStorage(url: url)
  }
}

// TODO: Audit unchecked sendable
public final class _FileStorage<Value: Codable & Sendable>: Persistent, @unchecked Sendable {
  @Dependency(\._fileStoragePersistenceQueue) fileprivate var queue
  let url: URL
  var workItem: DispatchWorkItem?
  var notificationListener: Any!

  public init(url: URL) {
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
        self.queue.async(execute: DispatchWorkItem {
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

extension _FileStorage: Hashable {
  public static func == (lhs: _FileStorage, rhs: _FileStorage) -> Bool {
    lhs.url == rhs.url
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.url)
  }
}

@_spi(Internals)
public protocol FileStorageQueue: Sendable {
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

@_spi(Internals)
extension DispatchQueue: FileStorageQueue {
  private static let isSettingKey = DispatchSpecificKey<Bool>()

  public func asyncAfter(interval: DispatchTimeInterval, execute workItem: DispatchWorkItem) {
    self.asyncAfter(deadline: .now() + interval, execute: workItem)
  }

  public func isSetting() -> Bool? {
    self.getSpecific(key: Self.isSettingKey)
  }

  public func fileSystemSource(
    url: URL,
    eventMask: DispatchSource.FileSystemEvent,
    handler: @escaping () -> Void
  ) -> AnyCancellable {
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: open(url.path, O_EVTONLY),
      eventMask: eventMask,
      queue: self
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
    self.setSpecific(key: Self.isSettingKey, value: isSetting)
  }
}

@_spi(Internals)
public final class TestPersistenceQueue: FileStorageQueue, Sendable {
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

private enum PersistenceQueueKey: DependencyKey {
  static var liveValue: any FileStorageQueue {
    DispatchQueue(label: "co.pointfree.ComposableArchitecture._FileStorage")
  }
  static var previewValue: any FileStorageQueue {
    TestPersistenceQueue()
  }
  static var testValue: any FileStorageQueue {
    TestPersistenceQueue()
  }
}

extension DependencyValues {
  // TODO: should this be public? allows you to run app in simulator with mock persistence queue
  @_spi(Internals)
  public var _fileStoragePersistenceQueue: any FileStorageQueue {
    get { self[PersistenceQueueKey.self] }
    set { self[PersistenceQueueKey.self] = newValue }
  }
}

private var willResignNotificationName: Notification.Name? {
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
