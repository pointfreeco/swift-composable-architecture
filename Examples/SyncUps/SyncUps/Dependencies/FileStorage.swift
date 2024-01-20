import ComposableArchitecture
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
  @Dependency(\.dataManager) fileprivate var dataManager
  let url: URL
  let queue = DispatchQueue(label: "co.pointfree.ComposableArchitecture._FileStorage")
  let isSetting = DispatchSpecificKey<Bool>()
  var task: Task<Void, Never>?
  var workItem: DispatchWorkItem?

  public init(url: URL) {
    self.url = url
    #if canImport(AppKit) || canImport(UIKit)
      self.task = Task { [weak self] in
        let willResignActiveNotifications = await NotificationCenter.default.notifications(
          named: Application.willResignActiveNotification
        )
        for await _ in willResignActiveNotifications {
          guard let self else { return }
          if let workItem = self.workItem {
            self.queue.async(execute: workItem)
          }
        }
      }
    #endif
  }

  deinit {
    self.task?.cancel()
  }

  public func load() -> Value? {
    try? JSONDecoder().decode(Value.self, from: self.dataManager.load(from: self.url))
  }

  public func save(_ value: Value) {
    self.workItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.queue.setSpecific(key: self.isSetting, value: true)
      try? self.dataManager.save(JSONEncoder().encode(value), to: self.url)
      self.workItem = nil
    }
    self.workItem = workItem
    self.queue.asyncAfter(deadline: .now() + .seconds(5), execute: workItem)
  }

  public var updates: AsyncStream<Value> {
    AsyncStream { continuation in
      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: open(self.url.path, O_EVTONLY),
        eventMask: .write,
        queue: self.queue
      )
      continuation.onTermination = { [source = UncheckedSendable(source)] _ in
        source.wrappedValue.cancel()
      }
      source.setEventHandler {
        if self.queue.getSpecific(key: self.isSetting) == true {
          self.queue.setSpecific(key: self.isSetting, value: false)
        } else if let value = self.load() {
          continuation.yield(value)
        }
      }
      source.resume()
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

@DependencyClient
private struct DataManager: Sendable {
  var load: @Sendable (_ from: URL) throws -> Data
  var save: @Sendable (Data, _ to: URL) throws -> Void
}

extension DataManager: DependencyKey {
  static let liveValue = Self(
    load: { url in try Data(contentsOf: url) },
    save: { data, url in
      try FileManager.default
        .createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url)
    }
  )

  // TODO: Can this just be a no-op client instead?
  static var testValue: Self {
    let fileSystem = LockIsolated<[URL: Data]>([:])
    return DataManager(
      load: {
        guard let data = fileSystem[$0]
        else {
          struct LoadError: Error {}
          throw LoadError()
        }
        return data
      },
      save: { data, url in fileSystem.withValue { $0[url] = data } }
    )
  }
}

extension DependencyValues {
  fileprivate var dataManager: DataManager {
    get { self[DataManager.self] }
    set { self[DataManager.self] = newValue }
  }
}
