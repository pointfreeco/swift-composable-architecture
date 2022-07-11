public enum TaskResult<Success: Sendable>: Sendable {
  case success(Success)
  case failure(Error)

  public init(catching body: @Sendable () async throws -> Success) async {
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
      return equals(lhs, rhs)
    case (.success, .failure), (.failure, .success):
      return false
    }
  }
}

public func isEquatable(_ value: Any) -> Bool {
  value is any Equatable
}

public func equals(_ lhs: Any, _ rhs: Any) -> Bool {
  func open<A: Equatable>(_ lhs: A, _ rhs: Any) -> Bool {
    lhs == (rhs as? A)
  }

  guard
    let lhs = lhs as? any Equatable
  else {
    runtimeWarning(
      "Tried to compare a non-equatable error type: %@",
      ["\(type(of: lhs))"]
    )
    return false
  }

  return open(lhs, rhs)
}

func id<A>(
  _ a: A /* (Void, Bool, Int, String, ...) */
) -> A   /* (Void, Bool, Int, String, ...) */ {
  return a
}

// "for all x, P(x) is true"
// ∀x P(x)
// ∀x in the set of real numbers, x*x >= 0

//let x: <A> A
//let x: (Void, Bool, Int, ...)
//let x: All

//let x: <A: Equatable> A
//let x: (Bool, Int, String, ...)
//let x: all Equatable

// (Any) -> All
// (Any, (All) -> Void) -> Void
//_openExistential(<#T##ExistentialType#>, do: <#T##(ContainedType) -> ResultType#>)
//_openExistential(E, do: (A) -> R) -> R



func existentialFun(_ value: Any /* Void | Int | ... */) {

  func open(_ a: some Equatable) {
    a == a
  }

  _ = value as Any
//  _ = value as any Equatable

  guard let value = value as? any Equatable /* Bool | Int | ... */
  else { return }

  _ = value as Any
  _ = value as any Equatable
  open(value)
//  value == other
}

func foo() {
  let x: Int = 1
  let y: any Equatable = 1
//let y: Bool | Int | String | [Int] | [[Int]] | ... = 1

  let z: Any
//let z: Void | Bool | Int | String | [Void] | (Int) -> Bool | ...

  // "there exists an x such that P(x) is true"
  // ∃x P(x)
  // ∃x in the set of real numbers such that x*x > 0
}
