import Foundation
import Combine

extension Publisher {
  // replication of the intent of the bug posted; word of caution - this design pattern could easily be abused and perhaps causes "spooky action at a distance" - please use with caution.
  public func identifiedCancellation<Token: Hashable>(_ token: Token) -> Publishers.IdentifiedCancellation<Self, Token> {
    return Publishers.IdentifiedCancellation(self, token: token)
  }

  // replication of the intent of the bug posted
  public func cancelUponCompletion<Token: Hashable>(_ token: Token) -> AnyCancellable {
    let canceller = Subscribers.CancelUponCompletion<Output, Failure, Token>(token: token)
    subscribe(canceller)
    // the cancellation here for this should be an "ignore this stream" and DONT cancel things... else wise it might be confusing
    return AnyCancellable(canceller)
  }

  public static func cancel<Token: Hashable>(_ token: Token) -> AnyPublisher<Output, Failure> {
    Deferred { () -> Empty<Output, Failure> in 
      _ = Empty<Never, Never>(completeImmediately: true)
        .cancelUponCompletion(token)
      return Empty(completeImmediately: true)
    }
    .eraseToAnyPublisher()
  }
}

// This is the global holder for identified streams for cancellation
internal final class IdentifiedStreams {
  static let sharedIdentifiedStreams = IdentifiedStreams()
  private let lock = os_unfair_lock_t.allocate(capacity: 1) // NOTE: locks must be heap allocated to avoid class heap to stack promotion optimizations.
  // we store the token to streams that use that token
  private var activeStreams = [AnyHashable : [CombineIdentifier : () -> Void]]()

  private init() {
    lock.initialize(to: os_unfair_lock_s())
  }

  deinit {
    lock.deallocate()
  }

  // insert a stream in the registration for potential cancellation
  func registerStream<Token: Hashable, C: Cancellable & CustomCombineIdentifierConvertible>(_ stream: C, for token: Token) {
    let key = AnyHashable(token)
    os_unfair_lock_lock(lock)
    activeStreams[key, default: [:]][stream.combineIdentifier] = stream.cancel
    print("registerStream", "activeStreams", activeStreams)
    os_unfair_lock_unlock(lock)
  }

  // remove a given stream since it is terminal or no longer wants to participate in the global cancellation concept
  func unregisterStream<Token: Hashable, C: Cancellable & CustomCombineIdentifierConvertible>(_ stream: C, for token: Token) {
    let key = AnyHashable(token)
    os_unfair_lock_lock(lock)
    withExtendedLifetime(activeStreams[key]?[stream.combineIdentifier]) {
      activeStreams[key]?[stream.combineIdentifier] = nil
      print("unregisterStream", "activeStreams", activeStreams)
      os_unfair_lock_unlock(lock)
    }
  }

  // the meat of how cancellation here works
  func cancelStreams<Token: Hashable>(_ token: Token) {
    let key = AnyHashable(token)
    os_unfair_lock_lock(lock)
    let streams = activeStreams[key]?.values
    activeStreams[key] = nil
    os_unfair_lock_unlock(lock)
    streams?.forEach { $0() } // this MUST be outside of the lock since it can cause an unregister
  }
}

extension Publishers {
  // This operator is the description of how a stream can be cancelled from an external token source
  public struct IdentifiedCancellation<Upstream: Publisher, Token: Hashable>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    public let upstream: Upstream
    public let token: Token

    public init(_ upstream: Upstream, token: Token) {
      self.upstream = upstream
      self.token = token
    }

    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
      upstream.subscribe(Inner(subscriber, token: token))
    }

    final class Inner<Downstream: Subscriber>: Subscriber, Subscription where Downstream.Input == Output, Downstream.Failure == Failure {
      typealias Input = Downstream.Input
      typealias Failure = Downstream.Failure

      enum State {
        case awaitingSubscription
        case subscribed(Subscription)
        case terminal
      }

      var state = State.awaitingSubscription
      let lock = os_unfair_lock_t.allocate(capacity: 1)
      let downstream: Downstream
      let token: Token


      init(_ downstream: Downstream, token: Token) {
        self.downstream = downstream
        self.token = token
        lock.initialize(to: os_unfair_lock_s())
      }

      deinit {
        lock.deallocate()
      }

      func receive(subscription: Subscription) {
        os_unfair_lock_lock(lock)
        // receiving subscriptions should only happen once, other occurances just cancel them since they are no longer relevant
        guard case .awaitingSubscription = state else {
          os_unfair_lock_unlock(lock)
          subscription.cancel()
          return
        }
        state = .subscribed(subscription)
        os_unfair_lock_unlock(lock)
        // since we are now going to be active, register this stream with the given token (perhaps this could be moved to the init? depends on semantics of this concept...
        IdentifiedStreams.sharedIdentifiedStreams.registerStream(self, for: token)
        // send ourselves downstream to start things up
        downstream.receive(subscription: self)
      }

      // this is just a pass through with a check to ensure not to send values if cancelled or completed/failed (aka terminal)
      func receive(_ input: Downstream.Input) -> Subscribers.Demand {
        os_unfair_lock_lock(lock)
        guard case .subscribed = state else {
          os_unfair_lock_unlock(lock)
          return .none
        }
        os_unfair_lock_unlock(lock)
        return downstream.receive(input)
      }

      func receive(completion: Subscribers.Completion<Downstream.Failure>) {
        os_unfair_lock_lock(lock)
        // we can only finish what has been started... other cases (e.g. cancelled) just ignore this.
        guard case .subscribed = state else {
          os_unfair_lock_unlock(lock)
          return
        }
        state = .terminal
        os_unfair_lock_unlock(lock)
        // since we are now in a terminal state we remove self from the participation of the external cancellation
        IdentifiedStreams.sharedIdentifiedStreams.unregisterStream(self, for: token)
        // send the completion downstream
        downstream.receive(completion: completion)
      }

      // demand here is pass-through as long as it is "active"
      func request(_ demand: Subscribers.Demand) {
        os_unfair_lock_lock(lock)
        guard case let .subscribed(upstream) = state else {
          os_unfair_lock_unlock(lock)
          return
        }
        os_unfair_lock_unlock(lock)
        upstream.request(demand)
      }

      func cancel() {
        os_unfair_lock_lock(lock)
        guard case let .subscribed(upstream) = state else {
          state = .terminal
          os_unfair_lock_unlock(lock)
          return
        }
        state = .terminal
        os_unfair_lock_unlock(lock)
        // since we are now in a terminal state we remove self from the participation of the external cancellation
        IdentifiedStreams.sharedIdentifiedStreams.unregisterStream(self, for: token)
        // send the cancellation upstream
        upstream.cancel()
      }
    }
  }
}

extension Subscribers {
  // this Subscriber cancels all streams that are reigstered with a given token identifier (perhaps it could be restricted to Never Input and Never Failure?)
  public final class CancelUponCompletion<Input, Failure: Error, Token: Hashable>: Subscriber, Cancellable {
    public let token: Token
    let lock = os_unfair_lock_t.allocate(capacity: 1)
    var subscription: Subscription?

    public init(token: Token) {
      self.token = token
      lock.initialize(to: os_unfair_lock_s())
    }

    public func receive(subscription: Subscription) {
      os_unfair_lock_lock(lock)
      guard self.subscription == nil else {
        os_unfair_lock_unlock(lock)
        subscription.cancel()
        return
      }
      self.subscription = subscription
      os_unfair_lock_unlock(lock)
      // ensure to kick off demand to start up any given upstream
      subscription.request(.unlimited)
    }

    public func receive(_ input: Input) -> Subscribers.Demand {
      return .none
    }

    public func receive(completion: Subscribers.Completion<Failure>) {
      os_unfair_lock_lock(lock)
      guard self.subscription != nil else {
        os_unfair_lock_unlock(lock)
        return
      }
      // the subscription is potentially external code that might have locks etc in it's deinit, so extend it past the unlock
      withExtendedLifetime(self.subscription) {
        self.subscription = nil
        os_unfair_lock_unlock(lock)
        // Here is the callout to the workhorse function
        IdentifiedStreams.sharedIdentifiedStreams.cancelStreams(token)
      }
    }

    public func cancel() {
      // clean up self here
      os_unfair_lock_lock(lock)
      guard self.subscription != nil else {
        os_unfair_lock_unlock(lock)
        return
      }
      withExtendedLifetime(self.subscription) {
        self.subscription = nil
        os_unfair_lock_unlock(lock)
      }
    }
  }
}
