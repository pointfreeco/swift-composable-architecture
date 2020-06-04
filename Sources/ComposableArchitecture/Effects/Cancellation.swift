import Combine
import Foundation

extension Effect {
  public static func cancel(id: AnyHashable) -> Effect {
    return .fireAndForget {
      cancellablesLock.sync {
        cancellationCancellables[id]?.forEach { $0.cancel() }
      }
    }
  }

  public func cancellable(id: AnyHashable, cancelInFlight: Bool = false) -> Effect {
    let effect = Deferred { () -> AnyPublisher<Output, Failure> in
      let subject = PassthroughSubject<Output, Failure>()
      let cancellable = self.subscribe(subject)

      var cancellationCancellable: AnyCancellable!
      cancellationCancellable = AnyCancellable {
        subject.send(completion: .finished)
        cancellablesLock.sync {
          cancellable.cancel()
          cancellationCancellables[id]?.remove(cancellationCancellable)
          if cancellationCancellables[id]?.isEmpty == .some(true) {
            cancellationCancellables[id] = nil
          }
        }
      }

      cancellablesLock.sync {
        cancellationCancellables[id, default: []].insert(
          cancellationCancellable
        )
      }

      return subject
        .handleEvents(
          receiveCompletion: { _ in cancellationCancellable.cancel() },
          receiveCancel: { cancellationCancellable.cancel() }
        )
        .eraseToAnyPublisher()
    }
    .eraseToEffect()

    return cancelInFlight ? .concatenate(.cancel(id: id), effect) : effect
  }
}

var cancellationCancellables: [AnyHashable: Set<AnyCancellable>] = [:]
let cancellablesLock = NSRecursiveLock()

//extension Effect {
//  /// Turns an effect into one that is capable of being canceled.
//  ///
//  /// To turn an effect into a cancellable one you must provide an identifier, which is used in
//  /// `Effect.cancel(id:)` to identify which in-flight effect should be canceled. Any hashable
//  /// value can be used for the identifier, such as a string, but you can add a bit of protection
//  /// against typos by defining a new type that conforms to `Hashable`, such as an empty struct:
//  ///
//  ///     struct LoadUserId: Hashable {}
//  ///
//  ///     case .reloadButtonTapped:
//  ///       // Start a new effect to load the user
//  ///       return environment.loadUser
//  ///         .map(Action.userResponse)
//  ///         .cancellable(id: LoadUserId(), cancelInFlight: true)
//  ///
//  ///     case .cancelButtonTapped:
//  ///       // Cancel any in-flight requests to load the user
//  ///       return .cancel(id: LoadUserId())
//  ///
//  /// - Parameters:
//  ///   - id: The effect's identifier.
//  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
//  ///     canceled before starting this new one.
//  /// - Returns: A new effect that is capable of being canceled by an identifier.
//  public func cancellable(id: AnyHashable, cancelInFlight: Bool = false) -> Effect {
//    return Deferred { () -> Publishers.HandleEvents<PassthroughSubject<Output, Failure>> in
//      let subject = PassthroughSubject<Output, Failure>()
//      let uuid = UUID()
//
//      cancellablesLock.sync {
//        if cancelInFlight {
//          cancellationCancellables[id]?.forEach { _, cancellable in cancellable.cancel() }
//          cancellationCancellables[id] = nil
//        }
//
//        let cancellable = self.subscribe(subject)
//
//        cancellationCancellables[id, default: [:]][uuid] = AnyCancellable {
//          cancellable.cancel()
//          subject.send(completion: .finished)
//        }
//      }
//
//      func cleanUp() {
//        cancellablesLock.sync {
//          toCancel.insert(uuid)
//          guard !isCancelling.contains(id) else { return }
//          isCancelling.insert(id)
//          defer { isCancelling.remove(id) }
//          toCancel.forEach { uuid in cancellationCancellables[id]?[uuid] = nil }
//          if cancellationCancellables[id]?.isEmpty == true {
//            cancellationCancellables[id] = nil
//          }
//          toCancel.removeAll()
//        }
//      }
//
//      return subject.handleEvents(
//        receiveCompletion: { _ in cleanUp() },
//        receiveCancel: cleanUp
//      )
//    }
//    .eraseToEffect()
//  }
//
//  /// An effect that will cancel any currently in-flight effect with the given identifier.
//  ///
//  /// - Parameter id: An effect identifier.
//  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
//  ///   identifier.
//  public static func cancel(id: AnyHashable) -> Effect {
//    .fireAndForget {
//      cancellablesLock.sync {
//        cancellationCancellables[id]?.forEach { _, cancellable in cancellable.cancel() }
//        cancellationCancellables[id] = nil
//      }
//    }
//  }
//}
//
//var cancellationCancellables: [AnyHashable: [UUID: AnyCancellable]] = [:]
//let cancellablesLock = NSRecursiveLock()
var isCancelling: Set<AnyHashable> = []
//var toCancel: Set<UUID> = []
