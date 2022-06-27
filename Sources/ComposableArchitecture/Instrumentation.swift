import Foundation

/// Interface to enable tracking/instrumenting the activity within TCA as ``Actions`` are sent into ``Store``s and
/// ``ViewStores``, ``Reducers`` are executed, and ``Effects`` are observed.
///
/// Additionally it can also track where `ViewStore` instances's are created.
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
///       Any Stores that have been created via scoping off the current Store object will have their states updated at this point too, thus there may be multiple instances of `.pre|.post` `.(view)[sS]toreChangeState` and `.pre|post` `.viewStoreDeduplicate` contained within a `.pre|.post` `.storeChangeState`
///       .pre, .viewStoreDeduplicate for impacted ViewStores
///       The existing state of the ViewStore instance is compared newly generated state and determined if it is a duplicate (this is unique to our branch of TCA)
///       .post, .viewStoreDeduplicate
///       .pre, .viewStoreChangeState
///       If the value for a ViewStores state was not a duplicate, then it is updated
///       .post, .viewStoreChangeState
///     .post, .storeChangeState
///   .post, .store.didSend
/// .post, .viewStoreSend
/// ```
public class Instrumentation {
  /// Type indicating the action being taken by the store
  public enum CallbackKind: CaseIterable, Hashable {
    case storeSend
    case storeToLocal
    case storeChangeState
    case storeProcessEvent
    case viewStoreSend
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
  let callback: Callback?

  /// Used to track when an instance of a `ViewStore` was created
  public typealias ViewStoreCreatedCallback = (_ instance: AnyObject, _ file: StaticString, _ line: UInt) -> Void
  let viewStoreCreated: ViewStoreCreatedCallback?

  public static let noop = Instrumentation()
  public static var shared: Instrumentation = .noop

  public init(callback: Callback? = nil, viewStoreCreated: ViewStoreCreatedCallback? = nil) {
    self.callback = callback
    self.viewStoreCreated = viewStoreCreated
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

    init(storeKind: StoreKind, action: Action? = nil, originatingAction: Action? = nil) {
      self.storeKind = storeKind
      self.action = action
      self.originatingAction = originatingAction
    }

    func eraseToAny() -> CallbackInfo<Any, Any> {
      return .init(storeKind: (storeKind as Any), action: action.map { $0 as Any }, originatingAction: originatingAction.map { $0 as Any })
    }
  }
}
