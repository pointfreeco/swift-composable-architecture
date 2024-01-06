import Combine
import Foundation

final class CurrentValueRelay<Output>: Publisher {
  typealias Failure = Never

  private var currentValue: Output
  private var subscriptions: [Subscription<AnySubscriber<Output, Failure>>] = []
  private let lock: os_unfair_lock_t

  var value: Output {
    get { self.currentValue }
    set { self.send(newValue) }
  }

  init(_ value: Output) {
    self.currentValue = value
    self.lock = os_unfair_lock_t.allocate(capacity: 1)
    self.lock.initialize(to: os_unfair_lock())
  }

  deinit {
    self.lock.deinitialize(count: 1)
    self.lock.deallocate()
  }

  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
    let subscription = Subscription(upstream: self, downstream: AnySubscriber(subscriber))
    self.lock.sync {
      self.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
    subscription.forwardValueToBuffer(self.currentValue)
  }

  func send(_ value: Output) {
    self.currentValue = value
    for subscription in self.subscriptions {
      subscription.forwardValueToBuffer(value)
    }
  }

  fileprivate func remove(subscription: AnyObject) {
    self.lock.sync {
      guard let index = subscriptions.firstIndex(where: { $0 === subscription })
      else { return }
      self.subscriptions.remove(at: index)
    }
  }
}

extension CurrentValueRelay {
  final class Subscription<Downstream: Subscriber>: Combine.Subscription
  where Downstream.Input == Output, Downstream.Failure == Failure {
    private weak var upstream: CurrentValueRelay?
    private var demandBuffer: DemandBuffer<Downstream>?

    init(upstream: CurrentValueRelay, downstream: Downstream) {
      self.upstream = upstream
      self.demandBuffer = DemandBuffer(subscriber: downstream)
    }

    func forwardValueToBuffer(_ value: Output) {
      _ = self.demandBuffer?.buffer(value: value)
    }

    func request(_ demand: Subscribers.Demand) {
      _ = self.demandBuffer?.demand(demand)
    }

    func cancel() {
      self.demandBuffer = nil
      self.upstream?.remove(subscription: self)
    }
  }
}
