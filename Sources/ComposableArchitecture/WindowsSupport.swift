#if canImport(OpenCombine)
import OpenCombine
#else
import Combine
#endif

#if canImport(Combine)
  typealias CombineSubscription = Combine.Subscription
  public typealias CombineSubscriber = Combine.Subscriber
#else
  typealias CombineSubscription = OpenCombine.Subscription
  public typealias CombineSubscriber = OpenCombine.Subscriber
#endif

#if os(Windows)
// provide missing symbols from Dispatch
public let NSEC_PER_MSEC: UInt64 = 1_000_000
public let NSEC_PER_SEC: UInt64 = 1_000_000_000
#endif

// `Dependencies` gates some Dependencies on `Combine` (vs `OpenCombineShim`).
// So temporarily add our own versions here.
// Could maybe allow Dependencies to work with `OpenCombine` also?
#if !canImport(Combine)
import CombineSchedulers
import Dependencies
import Dispatch
import Foundation
import OpenCombineDispatch
import OpenCombineSchedulers

extension DependencyValues {
    public var mainQueue: AnySchedulerOf<DispatchQueue> {
      get { self[MainQueueKey.self] }
      set { self[MainQueueKey.self] = newValue }
    }

    private enum MainQueueKey: DependencyKey {
      static let liveValue = AnySchedulerOf<DispatchQueue>.main
      static let testValue = AnySchedulerOf<DispatchQueue>
        .unimplemented(#"@Dependency(\.mainQueue)"#)
    }
}

extension DependencyValues {
  public var mainRunLoop: AnySchedulerOf<RunLoop> {
    get { self[MainRunLoopKey.self] }
    set { self[MainRunLoopKey.self] = newValue }
  }

  private enum MainRunLoopKey: DependencyKey {
    static let liveValue = AnySchedulerOf<RunLoop>.main
    static let testValue = AnySchedulerOf<RunLoop>.unimplemented(#"@Dependency(\.mainRunLoop)"#)
  }
}

#endif
