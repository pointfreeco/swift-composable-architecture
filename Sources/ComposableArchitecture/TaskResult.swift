import Foundation

public enum TaskResult<Success> {
  case success(Success)
  case failure(Error)

  public init(catching body: () async throws -> Success) async {
    do {
      self = .success(try await body())
    } catch {
      self = .failure(error)
    }
  }
}

extension TaskResult: Equatable where Success: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case let (.success(lhs), .success(rhs)):
      return lhs == rhs
    case let (.failure(lhs), .failure(rhs)):
      return isEqual(lhs, rhs) || ((lhs as NSError) == (rhs as NSError))
    case (.success, .failure), (.failure, .success):
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
      guard ComposableArchitecture.hash(failure, into: &hasher)
      else {
        hasher.combine(failure as NSError)
        return
      }
    }
  }
}

func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
  func open<LHS>(_: LHS.Type) -> Bool? {
    (Box<LHS>.self as? AnyEquatable.Type)?.isEqual(lhs, rhs)
  }
  return _openExistential(type(of: lhs), do: open) ?? false
}

private enum Box<T> {}

private protocol AnyEquatable {
  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool
}

extension Box: AnyEquatable where T: Equatable {
  fileprivate static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    lhs as? T == rhs as? T
  }
}

private protocol AnyHashable {
  static func hash(_ value: Any, into hasher: inout Hasher) -> Void
}
extension Box: AnyHashable where T: Hashable {
  static func hash(_ value: Any, into hasher: inout Hasher) {
    (value as? T).hash(into: &hasher)
  }
}
func hash(_ value: Any, into hasher: inout Hasher) -> Bool {
  func open<LHS>(_: LHS.Type) -> Void? {
    (Box<LHS>.self as? AnyHashable.Type)?.hash(value, into: &hasher)
  }
  return _openExistential(type(of: value), do: open) != nil
}
