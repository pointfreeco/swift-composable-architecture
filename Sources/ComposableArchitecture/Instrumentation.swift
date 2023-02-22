import Foundation

/// Interface to enable tracking/instrumenting the activity within TCA as ``Actions`` are sent into ``Store``s and
/// ``ViewStores``, ``Reducers`` are executed, and ``Effects`` are observed.
///
/// Additionally it can also track where `ViewStore` / `Store` instances's are created.
///
/// The way the library will call the closures provided is identical to the way that the ``Actions`` and ``Effects`` are
/// handled internally. That means that there are likely to be ``Instrumentation.ViewStore`` `will|did` pairs contained
/// within the bounds of an ``Instrumentation.Store`` `will|did` pair. For example: Consider sending a simple ``Action``
/// into a ``ViewStore`` that does not produce any synchronous ``Effects`` from the ``Reducer``, and the ``ViewStore``
/// scoped off a parent ``Store``s state:
/// ```
/// ViewStore.send(.someAction)
/// .pre, .viewStoreSend
///   Store.send(.someAction)
///   .pre, .storeSend
///     The Store will begin processing .someAction
///     .pre, .storeProcessEvent
///       The Store's reducer handles .someAction
///       Any returned actions from the reducer are queued up
///     .post, .storeProcessEvent
///     The above(willProcess -> didProcess) is repeated for each queued up action within Store
///     .pre, .storeChangeState
///       The Store updates its state
///       For each child Store scoped off the Store using a scoped local state
///         The Store computes the scoped local state
///         .pre, .scopedStoreToLocal
///         .post, .scopedStoreToLocal
///         The Store determines if the scoped local state is has changed
///         .pre, .scopedStoreDeduplicate
///         .post, .scopedtoreDeduplicate
///         If the scoped local state has changed then the scoped child Store's state is updated, along with any further
///         downstream scoped Stores
///         .pre, .scopedStoreChangeState
///         .post, .scopedStoreChangeState
///       For each ViewStore subscribed to a Store, if the state has changed will have their states updated at this too,
///       thus there may be multiple instances of the below
///         .pre, .viewStoreDeduplicate for impacted ViewStores
///         The existing state of the ViewStore instance is compared newly generated state and determined if it is a duplicate (this is unique to our branch of TCA)
///         .post, .viewStoreDeduplicate
///         .pre, .viewStoreChangeState
///         If the value for a ViewStores state was not a duplicate, then it is updated
///         .post, .viewStoreChangeState
///     .post, .storeChangeState
///   .post, .store.didSend
/// .post, .viewStoreSend
/// ```
public class Instrumentation {
  /// Type indicating the action being taken by the store
  public enum CallbackKind: String, CaseIterable, Hashable {
    case storeSend
    case storeChangeState
    case storeProcessEvent
    case scopedStoreToLocal
    case scopedStoreDeduplicate
    case scopedStoreChangeState
    case viewStoreSend
    // TODO: ViewStore's now want an observe closure passed, so it's more obvious
    // to scope down before subscribing. Let's add another measure for this?
    // case viewStoreToLocalState
    case viewStoreChangeState
    case viewStoreDeduplicate
  }

  /// Type indicating if the callback is before or after the action being taken by the store
  public enum CallbackTiming {
    case pre
    case post
  }

  /// The method to implement if a user of ComposableArchitecture would like to be notified about the "life cycle" of
  /// the various stores within the app as an action is acted upon.
  /// - Parameter info: The store's type and action (optionally the originating action)
  /// - Parameter timing: When this callback is being invoked (pre|post)
  /// - Parameter kind: The store's activity that to which this callback relates (state update, deduplication, etc)
  public typealias Callback = (_ info: CallbackInfo<Any, Any>, _ timing: CallbackTiming, _ kind: CallbackKind) -> Void
  private(set) var callback: Callback?

  /// Used to track when/where an instance was created
  public typealias ObjectCreationCallback = (_ instance: AnyObject, _ file: StaticString, _ line: UInt) -> Void

  private(set) var viewStoreCreated: ObjectCreationCallback?
  private(set) var storeCreated: ObjectCreationCallback?

  public static let noop = Instrumentation()

    public init(callback: Callback? = nil, viewStoreCreated: ObjectCreationCallback? = nil, storeCreated: ObjectCreationCallback? = nil) {
    self.callback = callback
    self.viewStoreCreated = viewStoreCreated
    self.storeCreated = storeCreated
  }


  /// Used to update the instance with new callbacks. This needs to be used _only_ on the same queue as the root ``Store``
  /// instance.
  /// - Parameters:
  ///   - callback: The callback invoked during the "life cycle" of the various stores within the app as an action is
  ///   acted upon.
  ///   - viewStoreCreated: Used to track when/where an instance of a ``ViewStore`` was created
  ///   - storeCreated: Used to track when/where an instance of a ``Store`` was created
  public func update(callback: Callback? = nil, viewStoreCreated: ObjectCreationCallback? = nil, storeCreated: ObjectCreationCallback? = nil) {
    self.callback = callback
    self.viewStoreCreated = viewStoreCreated
    self.storeCreated = storeCreated
  }
}

extension Instrumentation {
  /// Object that holds the information that will be passed to any implementation that has provided a callback function
  public struct CallbackInfo<StoreKind, Action> {
    /// The ``Type`` of the store that the callback is being executed within/for; e.g. a ViewStore or Store.
    public let storeKind: StoreKind
    /// The action that was `sent` to the store.
    public let action: Action?
    /// In the case of a ``Store.send`` operation the ``action`` may be one returned from a reducer and thus have an
    /// "originating" action (that action which was passed to the reducer that then returned the current ``action``)
    public let originatingAction: Action?

    public let file: StaticString?
    public let line: UInt?

    init(storeKind: StoreKind, action: Action? = nil, originatingAction: Action? = nil, file: StaticString? = nil, line: UInt? = nil) {
      self.storeKind = storeKind
      self.action = action
      self.originatingAction = originatingAction
      self.file = file
      self.line = line
    }

    func eraseToAny() -> CallbackInfo<Any, Any> {
        return .init(storeKind: (storeKind as Any), action: action.map { $0 as Any }, originatingAction: originatingAction.map { $0 as Any }, file: file, line: line)
    }
  }
}
