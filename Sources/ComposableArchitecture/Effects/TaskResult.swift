import Foundation

public enum TaskResult<Success> {
  case success(Success)
  case failure(Error)

  #if canImport(_Concurrency) && compiler(>=5.5.2)
    public init(catching body: () async throws -> Success) async {
      do {
        self = .success(try await body())
      } catch {
        self = .failure(error)
      }
    }
  #endif
}

public typealias TaskFailure = TaskResult<Never>

extension TaskResult: Equatable where Success: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case let (.success(lhs), .success(rhs)):
      return lhs == rhs
    case let (.failure(lhs as NSError), .failure(rhs as NSError)):
      return lhs == rhs
    default:
      return false
    }
  }
}

extension TaskResult: Hashable where Success: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self {
    case let .success(success):
      hasher.combine(success)
    case let .failure(failure):
      hasher.combine(failure as NSError)
    }
  }
}
