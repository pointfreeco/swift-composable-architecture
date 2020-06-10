import RxSwift
import Foundation

extension Effect {
  /// Turns an effect into one that is capable of being canceled.
  ///
  /// To turn an effect into a cancellable one you must provide an identifier, which is used in
  /// `Effect.cancel(id:)` to identify which in-flight effect should be canceled. Any hashable
  /// value can be used for the identifier, such as a string, but you can add a bit of protection
  /// against typos by defining a new type that conforms to `Hashable`, such as an empty struct:
  ///
  ///     struct LoadUserId: Hashable {}
  ///
  ///     case .reloadButtonTapped:
  ///       // Start a new effect to load the user
  ///       return environment.loadUser
  ///         .map(Action.userResponse)
  ///         .cancellable(id: LoadUserId(), cancelInFlight: true)
  ///
  ///     case .cancelButtonTapped:
  ///       // Cancel any in-flight requests to load the user
  ///       return .cancel(id: LoadUserId())
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: A new effect that is capable of being canceled by an identifier.
  public func cancellable(id: AnyHashable, cancelInFlight: Bool = false) -> Effect {
    let effect = Observable.deferred { () -> Observable<Output> in
      cancellablesLock.lock()
      defer { cancellablesLock.unlock() }

      let subject = PublishSubject<Output>()
      let disposable = self.subscribe(subject)

      var disposeKey: CompositeDisposable.DisposeKey!
      var cancellationCancellable: Disposable!

      cancellationCancellable = Disposables.create {
        cancellablesLock.sync {
          subject.onCompleted()
          disposable.dispose()
          cancellationCancellables[id]?.remove(for: disposeKey)
          if cancellationCancellables[id]?.count == 0 {
            cancellationCancellables[id] = nil
          }
        }
      }

      disposeKey = cancellationCancellables[id, default: CompositeDisposable()].insert(
        cancellationCancellable
      )

      return subject.do(
        onCompleted: { cancellationCancellable.dispose() },
        onDispose: { cancellationCancellable.dispose() }
      )
    }
    .eraseToEffect()

    return cancelInFlight ? .concatenate(.cancel(id: id), effect) : effect
  }

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// - Parameter id: An effect identifier.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel(id: AnyHashable) -> Effect {
    return .fireAndForget {
      cancellablesLock.sync {
        cancellationCancellables[id]?.dispose()
      }
    }
  }
}

var cancellationCancellables: [AnyHashable: CompositeDisposable] = [:]
let cancellablesLock = NSRecursiveLock()
