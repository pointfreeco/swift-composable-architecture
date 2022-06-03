import Foundation

public enum TaskResult<Success> {
  case success(Success)
  case failure(Error)

  #if canImport(_Concurrency) && compiler(>=5.5.2)
    public init(catching body: @Sendable () async throws -> Success) async {
      do {
        self = .success(try await body())
      } catch {
        self = .failure(error)
      }
    }
  #endif
}

extension TaskResult: Sendable where Success: Sendable {}

public struct EquatableVoid: Equatable, Codable, Hashable {
  public init() {}
}

#if canImport(_Concurrency) && compiler(>=5.5.2)
  extension TaskResult where Success == EquatableVoid {
    public init(catching body: @Sendable () async throws -> Void) async {
      do {
        try await body()
        self = .success(.init())
      } catch {
        self = .failure(error)
      }
    }
  }
#endif

public typealias TaskFailure = TaskResult<Never>

extension TaskResult: Equatable where Success: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case let (.success(lhs), .success(rhs)):
      return lhs == rhs
    case let (.failure(lhs), .failure(rhs)):
      return isEqual(lhs, rhs) ?? ((lhs as NSError) == (rhs as NSError))
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

private func isEqual(_ a: Any, _ b: Any) -> Bool? {
  func `do`<A>(_: A.Type) -> Bool? {
    (Witness<A>.self as? AnyEquatable.Type)?.isEqual(a, b)
  }
  return _openExistential(type(of: a), do: `do`)
}

extension Witness: AnyEquatable where A: Equatable {
  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    guard
      let lhs = lhs as? A,
      let rhs = rhs as? A
    else { return false }
    return lhs == rhs
  }
}

private protocol AnyEquatable {
  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool
}

private enum Witness<A> {}

