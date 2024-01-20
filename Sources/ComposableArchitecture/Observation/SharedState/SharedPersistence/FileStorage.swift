import Combine
import Foundation

#if canImport(AppKit)
  import AppKit
  private typealias Application = NSApplication
#elseif canImport(UIKit)
  import UIKit
  private typealias Application = UIApplication
#endif

extension SharedPersistence {
  public static func fileStorage<Value: Codable>(_ url: URL) -> Self
  where Self == _FileStorage<Value> {
    _FileStorage(url: url)
  }
}

public final class _FileStorage<Value: Codable & Sendable>: @unchecked Sendable, SharedPersistence {
  @Dependency(\._fileStoragePersistenceQueue) fileprivate var queue
  let url: URL
  var workItem: DispatchWorkItem?
  var notificationListener: Any!

  public init(url: URL) {
    self.url = url
    #if canImport(AppKit) || canImport(UIKit)
      self.notificationListener = NotificationCenter.default.addObserver(
        forName: Application.willResignActiveNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        guard
          let self,
          let workItem = self.workItem
        else { return }
        self.queue.async(execute: workItem)
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
    self.queue.asyncAfter(interval: .seconds(5), execute: workItem)
  }

  public var updates: AsyncStream<Value> {
    AsyncStream { continuation in
      let cancellable = self.queue.fileSystemSource(
        fileDescriptor: open(self.url.path, O_EVTONLY),
        eventMask: .write
      ) {
        if self.queue.isSetting() == true {
          self.queue.setIsSetting(false)
        } else if let value = self.load() {
          continuation.yield(value)
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
public protocol PersistenceQueue: Sendable {
  func async(execute workItem: DispatchWorkItem)
  func asyncAfter(interval: DispatchTimeInterval, execute: DispatchWorkItem)
  func isSetting() -> Bool?
  func fileSystemSource(
    fileDescriptor: Int32,
    eventMask: DispatchSource.FileSystemEvent,
    handler: @escaping () -> Void
  ) -> AnyCancellable
  func load(from url: URL) throws -> Data
  func save(_ data: Data, to url: URL) throws
  func setIsSetting(_ isSetting: Bool)
}

@_spi(Internals)
extension DispatchQueue: PersistenceQueue {
  private static let isSettingKey = DispatchSpecificKey<Bool>()

  public func asyncAfter(interval: DispatchTimeInterval, execute workItem: DispatchWorkItem) {
    self.asyncAfter(deadline: .now() + interval, execute: workItem)
  }

  public func isSetting() -> Bool? {
    self.getSpecific(key: Self.isSettingKey)
  }

  public func fileSystemSource(
    fileDescriptor: Int32,
    eventMask: DispatchSource.FileSystemEvent,
    handler: @escaping () -> Void
  ) -> AnyCancellable {
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: eventMask,
      queue: self
    )
    source.setEventHandler(handler: handler)
    source.resume()
    return AnyCancellable {
      source.cancel()
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
public final class TestPersistenceQueue: PersistenceQueue, Sendable {
  private let _isSetting = LockIsolated<Bool?>(nil)
  public let fileSystem = LockIsolated<[URL: Data]>([:])
  private let scheduler: AnySchedulerOf<DispatchQueue>
  private let sourceHandler = LockIsolated<(() -> Void)?>(nil)

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
    fileDescriptor: Int32,
    eventMask: DispatchSource.FileSystemEvent,
    handler: @escaping () -> Void
  ) -> AnyCancellable {
    self.sourceHandler.setValue(handler)
    return AnyCancellable {
      self.sourceHandler.setValue(nil)
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
    self.sourceHandler.value?()
  }

  public func setIsSetting(_ isSetting: Bool) {
    self._isSetting.setValue(isSetting)
  }
}

private enum PersistenceQueueKey: DependencyKey {
  static var liveValue: any PersistenceQueue {
    DispatchQueue(label: "co.pointfree.ComposableArchitecture._FileStorage")
  }
  static var previewValue: any PersistenceQueue {
    TestPersistenceQueue()
  }
  static var testValue: any PersistenceQueue {
    TestPersistenceQueue()
  }
}

extension DependencyValues {
  // TODO: should this be public? allows you to run app in simulator with mock persistence queue
  @_spi(Internals)
  public var _fileStoragePersistenceQueue: any PersistenceQueue {
    get { self[PersistenceQueueKey.self] }
    set { self[PersistenceQueueKey.self] = newValue }
  }
}
