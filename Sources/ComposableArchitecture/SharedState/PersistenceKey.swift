/// A type that can load and subscribe to state in an external system.
///
/// Conform to this protocol to express loading state from an external system, and subscribing to
/// state changes in the external system. It is only necessary to conform to this protocol if the
/// ``AppStorageKey``, ``FileStorageKey``, or ``InMemoryKey`` strategies are not sufficient for your
/// use case.
///
/// See the article <doc:SharingState> for more information, in particular the
/// <doc:SharingState#Custom-persistence> section.
public protocol PersistenceReaderKey<Value>: Hashable {
  /// A type that can be loaded or subscribed to in an external system.
  associatedtype Value

  /// Loads the freshest value from storage. Returns `nil` if there is no value in storage.
  ///
  /// - Parameter initialValue: An initial value assigned to the `@Shared` property.
  /// - Returns: An initial value provided by an external system, or `nil`.
  func load(initialValue: Value?) -> Value?

  /// Subscribes to external updates.
  ///
  /// - Parameters:
  ///   - initialValue: An initial value assigned to the `@Shared` property.
  ///   - didSet: A closure that is invoked with new values from an external system, or `nil` if the
  ///     external system no longer holds a value.
  /// - Returns: A subscription to updates from an external system. If it is cancelled or
  ///   deinitialized, the `didSet` closure will no longer be invoked.
  func subscribe(
    initialValue: Value?,
    didSet: @Sendable @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription
}

extension PersistenceReaderKey {
  public func subscribe(
    initialValue: Value?,
    didSet: @Sendable @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    Shared.Subscription {}
  }
}

/// A type that can persist shared state to an external storage.
///
/// Conform to this protocol to express persistence to some external storage by describing how to
/// save to and load from the external storage, and providing a stream of values that represents
/// when the external storage is changed from the outside. It is only necessary to conform to this
/// protocol if the ``AppStorageKey``, ``FileStorageKey``, or ``InMemoryKey`` strategies are not
/// sufficient for your use case.
///
/// See the article <doc:SharingState> for more information, in particular the
/// <doc:SharingState#Custom-persistence> section.
public protocol PersistenceKey<Value>: PersistenceReaderKey {
  /// Saves a value to storage.
  func save(_ value: Value)
}

extension Shared {
  /// A subscription to a ``PersistenceReaderKey``'s updates.
  ///
  /// This object is returned from ``PersistenceReaderKey/subscribe(initialValue:didSet:)``, which
  /// will feed updates from an external system for its lifetime, or till ``cancel()`` is called.
  public class Subscription {
    let onCancel: () -> Void

    /// Initializes the subscription with the given cancel closure.
    ///
    /// - Parameter cancel: A closure that the `cancel()` method executes.
    public init(_ cancel: @escaping () -> Void) {
      self.onCancel = cancel
    }

    deinit {
      self.cancel()
    }

    /// Cancels the subscription.
    public func cancel() {
      self.onCancel()
    }
  }
}
