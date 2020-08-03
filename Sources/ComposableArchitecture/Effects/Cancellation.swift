import Combine
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
  public func cancellable<Id: Hashable>(id: Id, cancelInFlight: Bool = false) -> Effect {

    Deferred { () -> Self in

      let subject = cancellablesLock.sync { () -> PassthroughSubject<Void, Never> in
      if cancelInFlight {
        subjects[id]?.send(())
        subjects[id]?.send(completion: .finished)
        subjects[id] = nil
      }

      let subject = subjects[id] ?? PassthroughSubject<Void, Never>()
      subjects[id] = subject
        return subject
      }

      return self
        .prefix(untilOutputFrom: subject)
        .eraseToEffect()

    }
    .eraseToEffect()

  }

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// - Parameter id: An effect identifier.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel<Id: Hashable>(id: Id) -> Effect {
    .fireAndForget {
      cancellablesLock.sync {
      subjects[id]?.send(())
      subjects[id]?.send(completion: .finished)
      subjects[id] = nil
      }
    }

  }
}

var subjects: [AnyHashable: PassthroughSubject<Void, Never>] = [:]

var cancellationCancellables: [AnyHashable: Set<AnyCancellable>] = [:]
let cancellablesLock = NSRecursiveLock()
