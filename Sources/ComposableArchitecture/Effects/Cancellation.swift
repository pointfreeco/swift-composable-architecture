import Combine
import Foundation

extension Effect {
  /// Turns an effect into one that is capable of being canceled.
  ///
  /// To turn an effect into a cancellable one you must provide an identifier, which is used in
  /// ``Effect/cancel(id:)-iun1`` to identify which in-flight effect should be canceled. Any
  /// hashable value can be used for the identifier, such as a string, but you can add a bit of
  /// protection against typos by defining a new type for the identifier:
  ///
  /// ```swift
  /// struct LoadUserID {}
  ///
  /// case .reloadButtonTapped:
  ///   // Start a new effect to load the user
  ///   return environment.loadUser
  ///     .map(Action.userResponse)
  ///     .cancellable(id: LoadUserID.self, cancelInFlight: true)
  ///
  /// case .cancelButtonTapped:
  ///   // Cancel any in-flight requests to load the user
  ///   return .cancel(id: LoadUserID.self)
  /// ```
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: A new effect that is capable of being canceled by an identifier.
  public func cancellable(id: AnyHashable, cancelInFlight: Bool = false) -> Self {
    Deferred {
      ()
        -> Publishers.HandleEvents<
          Publishers.PrefixUntilOutput<Self, PassthroughSubject<Void, Never>>
        > in
      cancellablesLock.lock()
      defer { cancellablesLock.unlock() }

      let id = CancelToken(id: id)
      if cancelInFlight {
        cancellationCancellables[id]?.forEach { $0.cancel() }
      }

      let cancellationSubject = PassthroughSubject<Void, Never>()

      var cancellationCancellable: AnyCancellable!
      cancellationCancellable = AnyCancellable {
        cancellablesLock.sync {
          cancellationSubject.send(())
          cancellationSubject.send(completion: .finished)
          cancellationCancellables[id]?.remove(cancellationCancellable)
          if cancellationCancellables[id]?.isEmpty == .some(true) {
            cancellationCancellables[id] = nil
          }
        }
      }

      return self.prefix(untilOutputFrom: cancellationSubject)
        .handleEvents(
          receiveSubscription: { _ in
            _ = cancellablesLock.sync {
              cancellationCancellables[id, default: []].insert(
                cancellationCancellable
              )
            }
          },
          receiveCompletion: { _ in cancellationCancellable.cancel() },
          receiveCancel: cancellationCancellable.cancel
        )
    }
    .eraseToEffect()
  }

  /// Turns an effect into one that is capable of being canceled.
  ///
  /// A convenience for calling ``Effect/cancellable(id:cancelInFlight:)-17skv`` with a static type
  /// as the effect's unique identifier.
  ///
  /// - Parameters:
  ///   - id: A unique type identifying the effect.
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: A new effect that is capable of being canceled by an identifier.
  public func cancellable(id: Any.Type, cancelInFlight: Bool = false) -> Self {
    self.cancellable(id: ObjectIdentifier(id), cancelInFlight: cancelInFlight)
  }

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// - Parameter id: An effect identifier.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel(id: AnyHashable) -> Self {
    .fireAndForget {
      cancellablesLock.sync {
        cancellationCancellables[.init(id: id)]?.forEach { $0.cancel() }
      }
    }
  }

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// A convenience for calling ``Effect/cancel(id:)-iun1`` with a static type as the effect's
  /// unique identifier.
  ///
  /// - Parameter id: A unique type identifying the effect.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel(id: Any.Type) -> Self {
    .cancel(id: ObjectIdentifier(id))
  }

  /// An effect that will cancel multiple currently in-flight effects with the given identifiers.
  ///
  /// - Parameter ids: An array of effect identifiers.
  /// - Returns: A new effect that will cancel any currently in-flight effects with the given
  ///   identifiers.
  public static func cancel(ids: [AnyHashable]) -> Self {
    .merge(ids.map(Effect.cancel(id:)))
  }

  /// An effect that will cancel multiple currently in-flight effects with the given identifiers.
  ///
  /// A convenience for calling ``Effect/cancel(ids:)-dmwy`` with a static type as the effect's
  /// unique identifier.
  ///
  /// - Parameter ids: An array of unique types identifying the effects.
  /// - Returns: A new effect that will cancel any currently in-flight effects with the given
  ///   identifiers.
  public static func cancel(ids: [Any.Type]) -> Self {
    .merge(ids.map(Effect.cancel(id:)))
  }
}

/// Execute an operation with a cancellation identifier.
///
/// If the operation is in-flight when `Task.cancel(id:)` is called with the same identifier, the
/// operation will be cancelled.
///
/// - Parameters:
///   - id: A unique identifier for the operation.
///   - cancelInFlight: Determines if any in-flight operation with the same identifier should be
///     canceled before starting this new one.
///   - operation: An async operation.
/// - Throws: An error thrown by the operation.
/// - Returns: A value produced by operation.
public func withTaskCancellation<T: Sendable>(
  id: AnyHashable,
  cancelInFlight: Bool = false,
  operation: @Sendable @escaping () async throws -> T
) async rethrows -> T {
  let task = { () -> Task<T, Error> in
    cancellablesLock.lock()
    let id = CancelToken(id: id)
    if cancelInFlight {
      cancellationCancellables[id]?.forEach { $0.cancel() }
    }
    let task = Task { try await operation() }
    var cancellable: AnyCancellable!
    cancellable = AnyCancellable {
      task.cancel()
      cancellablesLock.sync {
        cancellationCancellables[id]?.remove(cancellable)
        if cancellationCancellables[id]?.isEmpty == .some(true) {
          cancellationCancellables[id] = nil
        }
      }
    }
    cancellationCancellables[id, default: []].insert(cancellable)
    cancellablesLock.unlock()
    return task
  }()
  do {
    return try await task.cancellableValue
  } catch {
    return try Result<T, Error>.failure(error)._rethrowGet()
  }
}

/// Execute an operation with a cancellation identifier.
///
/// A convenience for calling ``withTaskCancellation(id:cancelInFlight:operation:)-4dtr6`` with a
/// static type as the operation's unique identifier.
///
/// - Parameters:
///   - id: A unique type identifying the operation.
///   - cancelInFlight: Determines if any in-flight operation with the same identifier should be
///     canceled before starting this new one.
///   - operation: An async operation.
/// - Throws: An error thrown by the operation.
/// - Returns: A value produced by operation.
public func withTaskCancellation<T: Sendable>(
  id: Any.Type,
  cancelInFlight: Bool = false,
  operation: @Sendable @escaping () async throws -> T
) async rethrows -> T {
  try await withTaskCancellation(
    id: ObjectIdentifier(id),
    cancelInFlight: cancelInFlight,
    operation: operation
  )
}

extension Task where Success == Never, Failure == Never {
  /// Cancel any currently in-flight operation with the given identifier.
  ///
  /// - Parameter id: An identifier.
  public static func cancel<ID: Hashable & Sendable>(id: ID) async {
    await MainActor.run {
      cancellablesLock.sync { cancellationCancellables[.init(id: id)]?.forEach { $0.cancel() } }
    }
  }

  /// Cancel any currently in-flight operation with the given identifier.
  ///
  /// A convenience for calling `Task.cancel(id:)` with a static type as the operation's unique
  /// identifier.
  ///
  /// - Parameter id: A unique type identifying the operation.
  public static func cancel(id: Any.Type) async {
    await self.cancel(id: ObjectIdentifier(id))
  }
}

struct CancelToken: Hashable {
  let id: AnyHashable
  let discriminator: ObjectIdentifier

  init(id: AnyHashable) {
    self.id = id
    self.discriminator = ObjectIdentifier(type(of: id.base))
  }
}

var cancellationCancellables: [CancelToken: Set<AnyCancellable>] = [:]
let cancellablesLock = NSRecursiveLock()

@rethrows
private protocol _ErrorMechanism {
  associatedtype Output
  func get() throws -> Output
}

extension _ErrorMechanism {
  internal func _rethrowError() rethrows -> Never {
    _ = try _rethrowGet()
    fatalError()
  }

  internal func _rethrowGet() rethrows -> Output {
    return try get()
  }
}

extension Result: _ErrorMechanism {}
