import XCTestDynamicOverlay

/// A value that represents either a Void or a failure. This type differs from Swift's `Result`
/// type in that it uses only one generic for the success case, leaving the failure case as an
/// untyped `Error`.
///
/// This type is needed because Swift's concurrency tools can only express untyped errors, such as
/// `async` functions and `AsyncSequence`, and so their output can realistically only be bridged to
/// `Result<_, Error>`. However, `Result<_, Error>` is never `Equatable` since `Error` is not
/// `Equatable`, and equatability is very important for testing in the Composable Architecture. By
/// defining our own type we get the ability to recover equatability in most situations.
///
/// If someday Swift gets typed `throws`, then we can eliminate this type and rely solely on
/// `Result`.
///
/// You typically use this type as the payload of an action which receives a response from an
/// effect:
///
/// ```swift
/// enum Action: Equatable {
///   case factButtonTapped
///   case factResponse(TaskVoidResult)
/// }
/// ```
///
/// Then you can model your dependency as using simple `async` and `throws` functionality:
///
/// ```swift
/// struct NumberFactClient {
///   var fetch: (Int) async throws -> Void
/// }
/// ```
///
/// And finally you can use ``Effect/run(priority:operation:catch:fileID:line:)`` to construct an
/// effect in the reducer that invokes the `numberFact` endpoint and wraps its response in a
/// ``TaskVoidResult`` by using its catching initializer, ``TaskVoidResult/init(catching:)``:
///
/// ```swift
/// case .factButtonTapped:
///   return .run { send in
///     await send(
///       .factResponse(
///         TaskVoidResult { try await self.numberFact.fetch(state.number) }
///       )
///     )
///   }
///
/// case .factResponse(.success):
///   // do something
///
/// case .factResponse(.failure):
///   // handle error
///
/// // ...
/// }
/// ```
public enum TaskVoidResult: Sendable {
  /// A success case
  case success
  
  /// A failure, storing an error.
  case failure(Error)
  
  /// Creates a new task result by evaluating an async throwing closure, capturing the returned
  /// value as a success, or any thrown error as a failure.
  ///
  /// This initializer is most often used in an async effect being returned from a reducer. See the
  /// documentation for ``TaskResult`` for a concrete example.
  ///
  /// - Parameter body: An async, throwing closure.
  @_transparent
  public init(catching body: @Sendable () async throws -> Void) async {
    do {
      try await body()
      self = .success
    } catch {
      self = .failure(error)
    }
  }
  
  /// Transforms a `Result` into a `TaskVoidResult`, erasing its `Failure` to `Error`.
  ///
  /// - Parameter result: A result.
  @inlinable
  public init<Failure>(_ result: Result<Void, Failure>) {
    switch result {
    case .success:
      self = .success
    case let .failure(error):
      self = .failure(error)
    }
  }
  
  /// Returns the void value as a throwing property.
  @inlinable
  public var value: Void {
    get throws {
      switch self {
      case .success:
        return
      case let .failure(error):
        throw error
      }
    }
  }
}

extension Result where Success == Void, Failure == Error {
  /// Transforms a `TaskVoidResult` into a `Result`.
  ///
  /// - Parameter result: A task result.
  @inlinable
  public init(_ result: TaskVoidResult) {
    switch result {
    case .success:
      self = .success(())
    case let .failure(error):
      self = .failure(error)
    }
  }
}

extension TaskVoidResult: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.success, .success):
      return true
    case let (.failure(lhs), .failure(rhs)):
      return _isEqual(lhs, rhs)
        ?? {
          #if DEBUG
            let lhsType = type(of: lhs)
            if TaskResultDebugging.emitRuntimeWarnings, lhsType == type(of: rhs) {
              let lhsTypeName = typeName(lhsType)
              runtimeWarn(
                """
                "\(lhsTypeName)" is not equatable. …

                To test two values of this type, it must conform to the "Equatable" protocol. For \
                example:

                    extension \(lhsTypeName): Equatable {}

                See the documentation of "TaskResult" for more information.
                """
              )
            }
          #endif
          return false
        }()
    default:
      return false
    }
  }
}

extension TaskVoidResult: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .success:
      hasher.combine(0)
    case let .failure(error):
      if let error = (error as Any) as? AnyHashable {
        hasher.combine(error)
        hasher.combine(1)
      } else {
        #if DEBUG
          if TaskResultDebugging.emitRuntimeWarnings {
            let errorType = typeName(type(of: error))
            runtimeWarn(
              """
              "\(errorType)" is not hashable. …

              To hash a value of this type, it must conform to the "Hashable" protocol. For example:

                  extension \(errorType): Hashable {}

              See the documentation of "TaskVoidResult" for more information.
              """
            )
          }
        #endif
      }
    }
  }
}

extension TaskVoidResult {
  // NB: For those that try to interface with `TaskVoidResult` using `Result`'s old API.
  @available(*, unavailable, renamed: "value")
  public func get() throws {
    try self.value
  }
}
