import ComposableArchitecture
import Foundation

extension SharedPersistence {
  static func fileStorage<Value: Codable>(_ url: URL) -> Self where Self == _FileStorage<Value> {
    _FileStorage(url: url)
  }
}

struct _FileStorage<Value: Codable>: SharedPersistence {
  @Dependency(\.dataManager) var dataManager
  let url: URL

  public func load() -> Value? {
    try? JSONDecoder().decode(Value.self, from: dataManager.load(from: self.url))
  }

  public func save(_ value: Value) {
    try? dataManager.save(JSONEncoder().encode(value), to: self.url)
  }
}

extension _FileStorage: Hashable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.url == rhs.url
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.url)
  }
}

@DependencyClient
struct DataManager: Sendable {
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

  static let testValue = Self()
}

extension DependencyValues {
  var dataManager: DataManager {
    get { self[DataManager.self] }
    set { self[DataManager.self] = newValue }
  }
}

extension DataManager {
  static func mock(initialData: Data? = nil) -> Self {
    let data = LockIsolated(initialData)
    return Self(
      load: { _ in
        guard let data = data.value
        else {
          struct FileNotFound: Error {}
          throw FileNotFound()
        }
        return data
      },
      save: { newData, _ in data.setValue(newData) }
    )
  }

  static let failToWrite = Self(
    load: { _ in Data() },
    save: { _, _ in
      struct SaveError: Error {}
      throw SaveError()
    }
  )

  static let failToLoad = Self(
    load: { _ in
      struct LoadError: Error {}
      throw LoadError()
    },
    save: { _, _ in }
  )
}
