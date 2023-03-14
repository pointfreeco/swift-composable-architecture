import Combine
import Foundation

extension EffectPublisher {
  /// Turns an effect into one that is capable of being canceled.
  ///
  /// To turn an effect into a cancellable one you must provide an identifier, which is used in
  /// ``EffectPublisher/cancel(id:)-6hzsl`` to identify which in-flight effect should be canceled.
  /// Any hashable value can be used for the identifier, such as a string, but you can add a bit of
  /// protection against typos by defining a new type for the identifier:
  ///
  /// ```swift
  /// struct LoadUserID {}
  ///
  /// case .reloadButtonTapped:
  ///   // Start a new effect to load the user
  ///   return self.apiClient.loadUser()
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
    @Dependency(\.navigationIDPath) var navigationIDPath
    switch self.operation {
    case .none:
      return .none
    case let .publisher(publisher):
      return Self(
        operation: .publisher(
          Deferred {
            ()
              -> Publishers.HandleEvents<
                Publishers.PrefixUntilOutput<
                  AnyPublisher<Action, Failure>, PassthroughSubject<Void, Never>
                >
              > in

            if cancelInFlight {
              _cancellationCancellables.cancel(id: id, navigationIDPath)
            }

            let cancellationSubject = PassthroughSubject<Void, Never>()

            var cancellationCancellable: AnyCancellable!
            cancellationCancellable = AnyCancellable {
              cancellationSubject.send(())
              cancellationSubject.send(completion: .finished)
              _cancellationCancellables.remove(cancellationCancellable, at: id, navigationIDPath)
            }

            return publisher.prefix(untilOutputFrom: cancellationSubject)
              .handleEvents(
                receiveSubscription: { _ in
                  _cancellationCancellables.insert(
                    cancellationCancellable, at: id, navigationIDPath
                  )
                },
                receiveCompletion: { _ in cancellationCancellable.cancel() },
                receiveCancel: cancellationCancellable.cancel
              )
          }
          .eraseToAnyPublisher()
        )
      )
    case let .run(priority, operation):
      return withEscapedDependencies { continuation in
        Self(
          operation: .run(priority) { send in
            await continuation.yield {
              await withTaskCancellation(id: id, cancelInFlight: cancelInFlight) {
                await operation(send)
              }
            }
          }
        )
      }
    }
  }

  /// Turns an effect into one that is capable of being canceled.
  ///
  /// A convenience for calling ``EffectPublisher/cancellable(id:cancelInFlight:)-29q60`` with a
  /// static type as the effect's unique identifier.
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
    @Dependency(\.navigationIDPath) var navigationIDPath
    return .fireAndForget {
      _cancellationCancellables.cancel(id: id, navigationIDPath)
    }
  }

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// A convenience for calling ``EffectPublisher/cancel(id:)-6hzsl`` with a static type as the
  /// effect's unique identifier.
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
    .merge(ids.map(EffectPublisher.cancel(id:)))
  }

  /// An effect that will cancel multiple currently in-flight effects with the given identifiers.
  ///
  /// A convenience for calling ``EffectPublisher/cancel(ids:)-1cqqx`` with a static type as the
  /// effect's unique identifier.
  ///
  /// - Parameter ids: An array of unique types identifying the effects.
  /// - Returns: A new effect that will cancel any currently in-flight effects with the given
  ///   identifiers.
  public static func cancel(ids: [Any.Type]) -> Self {
    .merge(ids.map(EffectPublisher.cancel(id:)))
  }
}

#if swift(>=5.7)
  /// Execute an operation with a cancellation identifier.
  ///
  /// If the operation is in-flight when `Task.cancel(id:)` is called with the same identifier, the
  /// operation will be cancelled.
  ///
  /// ```
  /// enum CancelID.self {}
  ///
  /// await withTaskCancellation(id: CancelID.self) {
  ///   // ...
  /// }
  /// ```
  ///
  /// ### Debouncing tasks
  ///
  /// When paired with a clock, this function can be used to debounce a unit of async work by
  /// specifying the `cancelInFlight`, which will automatically cancel any in-flight work with the
  /// same identifier:
  ///
  /// ```swift
  /// @Dependency(\.continuousClock) var clock
  /// enum CancelID {}
  ///
  /// // ...
  ///
  /// return .task {
  ///   await withTaskCancellation(id: CancelID.self, cancelInFlight: true) {
  ///     try await self.clock.sleep(for: .seconds(0.3))
  ///     return await .debouncedResponse(
  ///       TaskResult { try await environment.request() }
  ///     )
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - id: A unique identifier for the operation.
  ///   - cancelInFlight: Determines if any in-flight operation with the same identifier should be
  ///     canceled before starting this new one.
  ///   - operation: An async operation.
  /// - Throws: An error thrown by the operation.
  /// - Returns: A value produced by operation.
  @_unsafeInheritExecutor
  public func withTaskCancellation<T: Sendable>(
    id: AnyHashable,
    cancelInFlight: Bool = false,
    operation: @Sendable @escaping () async throws -> T
  ) async rethrows -> T {
    @Dependency(\.navigationIDPath) var navigationIDPath
    // FIXME: Re-synchronize?
    let (cancellable, task) = { () -> (AnyCancellable, Task<T, Error>) in
      if cancelInFlight {
        _cancellationCancellables.cancel(id: id, navigationIDPath)
      }
      let task = Task { try await operation() }
      let cancellable = AnyCancellable { task.cancel() }
      _cancellationCancellables.insert(cancellable, at: id, navigationIDPath)
      return (cancellable, task)
    }()
    defer {
      _cancellationCancellables.remove(cancellable, at: id, navigationIDPath)
    }
    do {
      return try await task.cancellableValue
    } catch {
      return try Result<T, Error>.failure(error)._rethrowGet()
    }
  }
#else
  public func withTaskCancellation<T: Sendable>(
    id: AnyHashable,
    cancelInFlight: Bool = false,
    operation: @Sendable @escaping () async throws -> T
  ) async rethrows -> T {
    @Dependency(\.navigationIDPath) var navigationIDPath
    let (cancellable, task) = _cancellablesLock.sync { () -> (AnyCancellable, Task<T, Error>) in
      if cancelInFlight {
        let cancelID = _CancelID(id: id, navigationIDPath: navigationIDPath)
        _cancellationCancellables[cancelID]?.forEach { $0.cancel() }
      }
      let task = Task { try await operation() }
      let cancellable = AnyCancellable { task.cancel() }
      for navigationIDPath in navigationIDPath.prefixes {
        let cancelID = _CancelID(id: id, navigationIDPath: navigationIDPath)
        _cancellationCancellables[cancelID, default: []].insert(cancellable)
      }
      return (cancellable, task)
    }
    defer {
      _cancellablesLock.sync {
        for navigationIDPath in navigationIDPath.prefixes {
          let cancelID = _CancelID(id: id, navigationIDPath: navigationIDPath)
          _cancellationCancellables[cancelID]?.remove(cancellable)
          if _cancellationCancellables[cancelID]?.isEmpty == .some(true) {
            _cancellationCancellables[cancelID] = nil
          }
        }
      }
    }
    do {
      return try await task.cancellableValue
    } catch {
      return try Result<T, Error>.failure(error)._rethrowGet()
    }
  }
#endif

#if swift(>=5.7)
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
  @_unsafeInheritExecutor
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
#else
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
#endif

extension Task where Success == Never, Failure == Never {
  /// Cancel any currently in-flight operation with the given identifier.
  ///
  /// - Parameter id: An identifier.
  public static func cancel<ID: Hashable & Sendable>(id: ID) {
    @Dependency(\.navigationIDPath) var navigationIDPath
    _cancellationCancellables.cancel(id: id, navigationIDPath)
  }

  /// Cancel any currently in-flight operation with the given identifier.
  ///
  /// A convenience for calling `Task.cancel(id:)` with a static type as the operation's unique
  /// identifier.
  ///
  /// - Parameter id: A unique type identifying the operation.
  public static func cancel(id: Any.Type) {
    self.cancel(id: ObjectIdentifier(id))
  }
}

@_spi(Internals) public struct _CancelID: Hashable {
  let id: AnyHashable
  let navigationIDPath: NavigationIDPath

  init(id: AnyHashable, navigationIDPath: NavigationIDPath) {
    self.id = id
    self.navigationIDPath = navigationIDPath
  }

  public init(_id id: AnyHashable) {
    self.id = id
    self.navigationIDPath = NavigationIDPath()
  }
}

@_spi(Internals) public var _cancellationCancellables = CancellationCancellables()

@rethrows
private protocol _ErrorMechanism {
  associatedtype Output
  func get() throws -> Output
}

extension _ErrorMechanism {
  func _rethrowError() rethrows -> Never {
    _ = try _rethrowGet()
    fatalError()
  }

  func _rethrowGet() rethrows -> Output {
    return try get()
  }
}

extension Result: _ErrorMechanism {}

@_spi(Internals)
public class CancellationCancellables {
  private var storage: [_CancelID: Set<AnyCancellable>] = [:]
  private let lock = NSRecursiveLock()

  func insert(
    _ cancellable: AnyCancellable, at id: AnyHashable, _ path: NavigationIDPath
  ) {
    self.lock.lock()
    defer { self.lock.unlock() }
    for navigationIDPath in path.prefixes {
      let cancelID = _CancelID(id: id, navigationIDPath: navigationIDPath)
      self.storage[cancelID, default: []].insert(cancellable)
    }
  }

  func remove(
    _ cancellable: AnyCancellable, at id: AnyHashable, _ path: NavigationIDPath
  ) {
    self.lock.lock()
    defer { self.lock.unlock() }
    // FIXME: Should this iterate over `path.prefixes`
    for path in path.prefixes {
      let cancelID = _CancelID(id: id, navigationIDPath: path)
      self.storage[cancelID]?.remove(cancellable)
      if self.storage[cancelID]?.isEmpty == true {
        self.storage[cancelID] = nil
      }
    }
  }

  func cancel(id: AnyHashable, _ path: NavigationIDPath) {
    self.lock.lock()
    defer { self.lock.unlock() }
    let cancelID = _CancelID(id: id, navigationIDPath: path)
    self.storage[cancelID]?.forEach { $0.cancel() }
  }

  @_spi(Internals)
  public func exists(at id: _CancelID) -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.storage[id] != nil
  }

  @_spi(Internals)
  public func removeAll() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.storage = [:]
  }

  @_spi(Internals)
  public var count: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.storage.count
  }
}
