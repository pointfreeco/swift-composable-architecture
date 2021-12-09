import Foundation

public enum TaskResult<Success> {
  case success(Success)
  case failure(Error)

  init(catching body: () async throws -> Success) async {
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
    case let (.failure(lhs as NSError), .failure(rhs as NSError)):
      return lhs == rhs
    default:
      return false
    }
  }
}

import ComposableArchitecture

extension Effect {
  public static func task<Value>(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> Value
  ) -> Self where Output == TaskResult<Value>, Failure == Never {
    return Effect.task {
      await .init { try await operation() }
    }
  }
}
