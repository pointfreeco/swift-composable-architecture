import Combine
import Foundation

extension Effect {
  /// Turns an effect into one that is capable of being canceled.
  ///
  /// To turn an effect into a cancellable one you must provide an identifier, which is used in
  /// ``Effect/cancel(id:)`` to identify which in-flight effect should be canceled.
  /// Any hashable value can be used for the identifier, such as a string, but you can add a bit of
  /// protection against typos by defining a new type for the identifier:
  ///
  /// ```swift
  /// enum CancelID { case loadUser }
  ///
  /// case .reloadButtonTapped:
  ///   // Start a new effect to load the user
  ///   return .run { send in
  ///     await send(
  ///       .userResponse(
  ///         TaskResult { try await self.apiClient.loadUser() }
  ///       )
  ///     )
  ///   }
  ///   .cancellable(id: CancelID.loadUser, cancelInFlight: true)
  ///
  /// case .cancelButtonTapped:
  ///   // Cancel any in-flight requests to load the user
  ///   return .cancel(id: CancelID.loadUser)
  /// ```
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: A new effect that is capable of being canceled by an identifier.
  public func cancellable<ID: Hashable>(id: ID, cancelInFlight: Bool = false) -> Self {
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
                  AnyPublisher<Action, Never>, PassthroughSubject<Void, Never>
                >
              > in
            _cancellablesLock.lock()
            defer { _cancellablesLock.unlock() }

            if cancelInFlight {
              _cancellationCancellables.cancel(id: id, path: navigationIDPath)
            }

            let cancellationSubject = PassthroughSubject<Void, Never>()

            var cancellable: AnyCancellable!
            cancellable = AnyCancellable {
              _cancellablesLock.sync {
                cancellationSubject.send(())
                cancellationSubject.send(completion: .finished)
                _cancellationCancellables.remove(cancellable, at: id, path: navigationIDPath)
              }
            }

            return publisher.prefix(untilOutputFrom: cancellationSubject)
              .handleEvents(
                receiveSubscription: { _ in
                  _cancellablesLock.sync {
                    _cancellationCancellables.insert(cancellable, at: id, path: navigationIDPath)
                  }
                },
                receiveCompletion: { _ in cancellable.cancel() },
                receiveCancel: cancellable.cancel
              )
          }
          .eraseToAnyPublisher()
        )
      )
    case let .run(priority, operation):
      return withEscapedDependencies { continuation in
        return Self(
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

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// - Parameter id: An effect identifier.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel<ID: Hashable>(id: ID) -> Self {
    let dependencies = DependencyValues._current
    @Dependency(\.navigationIDPath) var navigationIDPath
    // NB: Ideally we'd return a `Deferred` wrapping an `Empty(completeImmediately: true)`, but
    //     due to a bug in iOS 13.2 that publisher will never complete. The bug was fixed in
    //     iOS 13.3, but to remain compatible with iOS 13.2 and higher we need to do a little
    //     trickery to make sure the deferred publisher completes.
    return .publisher { () -> Publishers.CompactMap<Just<Action?>, Action> in
      DependencyValues.$_current.withValue(dependencies) {
        _cancellablesLock.sync {
          _cancellationCancellables.cancel(id: id, path: navigationIDPath)
        }
      }
      return Just<Action?>(nil).compactMap { $0 }
    }
  }
}

#if compiler(>=6)
  /// Execute an operation with a cancellation identifier.
  ///
  /// If the operation is in-flight when `Task.cancel(id:)` is called with the same identifier, the
  /// operation will be cancelled.
  ///
  /// ```swift
  /// enum CancelID { case timer }
  ///
  /// await withTaskCancellation(id: CancelID.timer) {
  ///   // Start cancellable timer...
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
  /// enum CancelID { case response }
  ///
  /// // ...
  ///
  /// return .run { send in
  ///   try await withTaskCancellation(id: CancelID.response, cancelInFlight: true) {
  ///     try await self.clock.sleep(for: .seconds(0.3))
  ///     await send(
  ///       .debouncedResponse(TaskResult { try await environment.request() })
  ///     )
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - id: A unique identifier for the operation.
  ///   - cancelInFlight: Determines if any in-flight operation with the same identifier should be
  ///     canceled before starting this new one.
  ///   - isolation: The isolation of the operation.
  ///   - operation: An async operation.
  /// - Throws: An error thrown by the operation.
  /// - Returns: A value produced by operation.
  public func withTaskCancellation<ID: Hashable, T>(
    id: ID,
    cancelInFlight: Bool = false,
    isolation: isolated (any Actor)? = #isolation,
    operation: sending @escaping @isolated(any) () async throws -> sending T
  ) async rethrows -> T {
    @Dependency(\.navigationIDPath) var navigationIDPath

    let (cancellable, task) = _cancellablesLock.sync { () -> (AnyCancellable, Task<T, Error>) in
      if cancelInFlight {
        _cancellationCancellables.cancel(id: id, path: navigationIDPath)
      }
      let task = Task { try await operation() }
      let cancellable = AnyCancellable { task.cancel() }
      _cancellationCancellables.insert(cancellable, at: id, path: navigationIDPath)
      return (cancellable, task)
    }
    defer {
      _cancellablesLock.sync {
        _cancellationCancellables.remove(cancellable, at: id, path: navigationIDPath)
      }
    }
    do {
      return try await task.cancellableValue
    } catch {
      return try Result<T, Error>.failure(error)._rethrowGet()
    }
  }
#else
  @_unsafeInheritExecutor
  public func withTaskCancellation<ID: Hashable, T: Sendable>(
    id: ID,
    cancelInFlight: Bool = false,
    operation: @Sendable @escaping () async throws -> T
  ) async rethrows -> T {
    @Dependency(\.navigationIDPath) var navigationIDPath

    let (cancellable, task) = _cancellablesLock.sync { () -> (AnyCancellable, Task<T, Error>) in
      if cancelInFlight {
        _cancellationCancellables.cancel(id: id, path: navigationIDPath)
      }
      let task = Task { try await operation() }
      let cancellable = AnyCancellable { task.cancel() }
      _cancellationCancellables.insert(cancellable, at: id, path: navigationIDPath)
      return (cancellable, task)
    }
    defer {
      _cancellablesLock.sync {
        _cancellationCancellables.remove(cancellable, at: id, path: navigationIDPath)
      }
    }
    do {
      return try await task.cancellableValue
    } catch {
      return try Result<T, Error>.failure(error)._rethrowGet()
    }
  }
#endif

extension Task<Never, Never> {
  /// Cancel any currently in-flight operation with the given identifier.
  ///
  /// - Parameter id: An identifier.
  public static func cancel<ID: Hashable>(id: ID) {
    @Dependency(\.navigationIDPath) var navigationIDPath

    return _cancellablesLock.sync {
      _cancellationCancellables.cancel(id: id, path: navigationIDPath)
    }
  }
}

@_spi(Internals) public struct _CancelID: Hashable {
  let discriminator: ObjectIdentifier
  let id: AnyHashable
  let navigationIDPath: NavigationIDPath

  init<ID: Hashable>(id: ID, navigationIDPath: NavigationIDPath) {
    self.discriminator = ObjectIdentifier(type(of: id))
    self.id = id
    self.navigationIDPath = navigationIDPath
  }
}

@_spi(Internals) public var _cancellationCancellables = CancellablesCollection()
private let _cancellablesLock = NSRecursiveLock()

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
public class CancellablesCollection {
  var storage: [_CancelID: Set<AnyCancellable>] = [:]

  func insert<ID: Hashable>(
    _ cancellable: AnyCancellable,
    at id: ID,
    path: NavigationIDPath
  ) {
    for navigationIDPath in path.prefixes {
      let cancelID = _CancelID(id: id, navigationIDPath: navigationIDPath)
      self.storage[cancelID, default: []].insert(cancellable)
    }
  }

  func remove<ID: Hashable>(
    _ cancellable: AnyCancellable,
    at id: ID,
    path: NavigationIDPath
  ) {
    for navigationIDPath in path.prefixes {
      let cancelID = _CancelID(id: id, navigationIDPath: navigationIDPath)
      self.storage[cancelID]?.remove(cancellable)
      if self.storage[cancelID]?.isEmpty == true {
        self.storage[cancelID] = nil
      }
    }
  }

  func cancel<ID: Hashable>(
    id: ID,
    path: NavigationIDPath
  ) {
    let cancelID = _CancelID(id: id, navigationIDPath: path)
    self.storage[cancelID]?.forEach { $0.cancel() }
    self.storage[cancelID] = nil
  }

  func exists<ID: Hashable>(
    at id: ID,
    path: NavigationIDPath
  ) -> Bool {
    self.storage[_CancelID(id: id, navigationIDPath: path)] != nil
  }

  public var count: Int {
    self.storage.count
  }

  public func removeAll() {
    self.storage.removeAll()
  }
}
