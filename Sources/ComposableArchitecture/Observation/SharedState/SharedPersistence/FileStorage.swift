#if canImport(Perception)
  import Foundation

  extension SharedPersistence {
    public static func json<Value: Codable>(
      _ filePath: URL,
      fileManager: FileManager = .default
    ) -> Self where Self == FileStorage<Value> {
      FileStorage(
        fileManager: fileManager,
        filePath: filePath
      )
    }
  }

  public struct FileStorage<Value: Codable>: SharedPersistence {
    let fileManager: FileManager
    let filePath: URL

    init(
      fileManager: FileManager,
      filePath: URL
    ) {
      self.fileManager = fileManager
      self.filePath = filePath
      try? self.fileManager.createDirectory(
        at: self.filePath.deletingLastPathComponent(), withIntermediateDirectories: true
      )
    }

    public func didSet(oldValue: Value, value: Value) {
      try? JSONEncoder().encode(value).write(to: self.filePath)
    }

    public func get() -> Value? {
      try? JSONDecoder().decode(Value.self, from: Data(contentsOf: self.filePath))
    }
  }

  extension FileStorage: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.filePath == rhs.filePath && lhs.fileManager == rhs.fileManager
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.fileManager)
      hasher.combine(self.filePath)
    }
}
#endif
