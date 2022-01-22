import Combine
import Foundation

extension Effect {
  /// Turns an effect into one that is capable of being canceled.
  ///
  /// To turn an effect into a cancellable one you must provide an identifier, which is used in
  /// ``Effect/cancel(id:)`` to identify which in-flight effect should be canceled. Any hashable
  /// value can be used for the identifier, such as a string, but you can add a bit of protection
  /// against typos by defining a new type that conforms to `Hashable`, such as an empty struct:
  ///
  /// ```swift
  /// struct LoadUserId: Hashable {}
  ///
  /// case .reloadButtonTapped:
  ///   // Start a new effect to load the user
  ///   return environment.loadUser
  ///     .map(Action.userResponse)
  ///     .cancellable(id: LoadUserId(), cancelInFlight: true)
  ///
  /// case .cancelButtonTapped:
  ///   // Cancel any in-flight requests to load the user
  ///   return .cancel(id: LoadUserId())
  /// ```
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: A new effect that is capable of being canceled by an identifier.
  public func cancellable(id: AnyHashable, cancelInFlight: Bool = false) -> Effect {
    Deferred {
      ()
        -> Publishers.HandleEvents<
          Publishers.PrefixUntilOutput<Self, PassthroughSubject<Void, Never>>
        > in
      cancellablesLock.lock()
      defer { cancellablesLock.unlock() }

      if cancelInFlight {
        cancellationCancellables[id]?.forEach { $0.cancel() }
      }

      let cancellationSubject = PassthroughSubject<Void, Never>()

      var cancellationCancellable: AnyCancellable!
      cancellationCancellable = AnyCancellable {
        cancellablesLock.sync {
          cancellationSubject.send(())
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

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// - Parameter id: An effect identifier.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel(id: AnyHashable) -> Effect {
    return .fireAndForget {
      cancellablesLock.sync {
        cancellationCancellables[id]?.forEach { $0.cancel() }
      }
    }
  }

  /// An effect that will cancel multiple currently in-flight effects with the given identifiers.
  ///
  /// - Parameter ids: A variadic list of effect identifiers.
  /// - Returns: A new effect that will cancel any currently in-flight effects with the given
  ///   identifiers.
  public static func cancel(ids: AnyHashable...) -> Effect {
    .cancel(ids: ids)
  }

  /// An effect that will cancel multiple currently in-flight effects with the given identifiers.
  ///
  /// - Parameter ids: An array of effect identifiers.
  /// - Returns: A new effect that will cancel any currently in-flight effects with the given
  ///   identifiers.
  public static func cancel(ids: [AnyHashable]) -> Effect {
    .merge(ids.map(Effect.cancel(id:)))
  }
}

var cancellationCancellables: [AnyHashable: Set<AnyCancellable>] = [:]
let cancellablesLock = NSRecursiveLock()

@propertyWrapper
public struct EffectID: Hashable {
  let effectIdentifier: EffectIdentifier

  public var wrappedValue: EffectIdentifier {
    effectIdentifier
  }

  static var currentContextID: AnyHashable? {
    Thread.current.threadDictionary.value(forKey: currentContextKey) as? AnyHashable
  }

  public init<ID>(
    wrappedValue: ID,
    file: String = #file,
    line: UInt = #line,
    column: UInt = #column
  ) where ID: Hashable {
    effectIdentifier = .init(
      contextID: Self.currentContextID,
      userData: wrappedValue,
      file: file,
      line: line,
      column: column
    )
  }

  public init(
    file: String = #file,
    line: UInt = #line,
    column: UInt = #column
  ) {
    effectIdentifier = .init(
      contextID: Self.currentContextID,
      file: file,
      line: line,
      column: column
    )
  }
}

public struct EffectIdentifier: Hashable {
  init(
    contextID: AnyHashable? = nil,
    userData: AnyHashable? = nil,
    file: String = #file,
    line: UInt = #line,
    column: UInt = #column
  ) {
    self.contextID = contextID
    self.userData = userData
    self.file = file
    self.line = line
    self.column = column
    #if DEBUG
      if contextID == nil {
        // TODO: Log some warning about the id not being store-specific?
      }
    #endif
  }

  let contextID: AnyHashable?
  let userData: AnyHashable?
  let file: String
  let line: UInt
  let column: UInt
}
