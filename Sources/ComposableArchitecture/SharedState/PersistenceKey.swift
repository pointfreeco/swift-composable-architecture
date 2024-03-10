#if canImport(Perception)
  /// A type that can persist shared state to an external storage.
  ///
  /// Conform to this protocol to express persistence to some external storage by describing how to
  /// save to and load from the external storage, and providing a stream of values that represents
  /// when the external storage is changed from the outside. It is only necessary to conform to
  /// this protocol if the ``appStorage(_:)-2ntx6``, ``fileStorage(_:)`` or ``inMemory(_:)``
  /// strategies are not sufficient for your use case.
  ///
  /// See the article <doc:SharingState> for more information, in particular the
  /// <doc:SharingState#Custom-persistence> section.
  public protocol PersistenceKey<Value>: Hashable {
    associatedtype Value

    /// Loads the freshest value from storage. Returns `nil` if there is no value in storage.
    func load(initialValue: Value?) -> Value?  // TODO: Should this be throwing?

    /// Saves a value to storage.
    func save(_ value: Value)

    /// Subscribes to external updates.
    func subscribe(
      initialValue: Value?, didSet: @escaping (_ newValue: Value?) -> Void
    ) -> Shared<Value>.Subscription
  }

  extension PersistenceKey {
    public func subscribe(
      initialValue: Value?, didSet: @escaping (_ newValue: Value?) -> Void
    ) -> Shared<Value>.Subscription {
      Shared.Subscription {}
    }
  }

  extension Shared {
    public class Subscription {
      let onCancel: () -> Void
      public init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
      }
      deinit {
        self.cancel()
      }
      func cancel() {
        self.onCancel()
      }
    }
  }

  enum PersistentReferencesKey: DependencyKey {
    static var liveValue: LockIsolated<[AnyHashable: any Reference]> {
      LockIsolated([:])
    }
    static var testValue: LockIsolated<[AnyHashable: any Reference]> {
      LockIsolated([:])
    }
  }
#endif
