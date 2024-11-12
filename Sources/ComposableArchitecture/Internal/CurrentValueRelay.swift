import Combine
import Foundation

final class CurrentValueRelay<Output>: Publisher {
  typealias Failure = Never

  private var currentValue: Output
  private let lock: os_unfair_lock_t
  private var subscriptions = ContiguousArray<Subscription>()

  var value: Output {
    get { self.lock.sync { self.currentValue } }
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

  func receive(subscriber: some Subscriber<Output, Never>) {
    let subscription = Subscription(upstream: self, downstream: subscriber)
    self.lock.sync {
      self.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }

  func send(_ value: Output) {
    let subscriptions = self.lock.sync {
      self.currentValue = value
      return self.subscriptions
    }
    for subscription in subscriptions {
      subscription.receive(value)
    }
  }

  private func remove(_ subscription: Subscription) {
    self.lock.sync {
      guard let index = self.subscriptions.firstIndex(of: subscription)
      else { return }
      self.subscriptions.remove(at: index)
    }
  }
}

extension CurrentValueRelay {
  fileprivate final class Subscription: Combine.Subscription, Equatable {
    private var demand = Subscribers.Demand.none
    private var downstream: (any Subscriber<Output, Never>)?
    private let lock: os_unfair_lock_t
    private var receivedLastValue = false
    private var upstream: CurrentValueRelay?

    init(upstream: CurrentValueRelay, downstream: any Subscriber<Output, Never>) {
      self.upstream = upstream
      self.downstream = downstream
      self.lock = os_unfair_lock_t.allocate(capacity: 1)
      self.lock.initialize(to: os_unfair_lock())
    }

    deinit {
      self.lock.deinitialize(count: 1)
      self.lock.deallocate()
    }

    func cancel() {
      self.lock.sync {
        self.downstream = nil
        self.upstream?.remove(self)
        self.upstream = nil
      }
    }

    func receive(_ value: Output) {
      self.lock.lock()

      guard let downstream else {
        self.lock.unlock()
        return
      }

      switch self.demand {
      case .unlimited:
        self.lock.unlock()
        // NB: Adding to unlimited demand has no effect and can be ignored.
        _ = downstream.receive(value)

      case .none:
        self.receivedLastValue = false
        self.lock.unlock()

      default:
        self.receivedLastValue = true
        self.demand -= 1
        self.lock.unlock()
        let moreDemand = downstream.receive(value)
        self.lock.sync {
          self.demand += moreDemand
        }
      }
    }

    func request(_ demand: Subscribers.Demand) {
      precondition(demand > 0, "Demand must be greater than zero")

      self.lock.lock()

      guard let downstream else {
        self.lock.unlock()
        return
      }

      self.demand += demand

      guard
        !self.receivedLastValue,
        let value = self.upstream?.value
      else {
        self.lock.unlock()
        return
      }

      self.receivedLastValue = true

      switch self.demand {
      case .unlimited:
        self.lock.unlock()
        // NB: Adding to unlimited demand has no effect and can be ignored.
        _ = downstream.receive(value)

      default:
        self.demand -= 1
        self.lock.unlock()
        let moreDemand = downstream.receive(value)
        self.lock.lock()
        self.demand += moreDemand
        self.lock.unlock()
      }
    }

    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
      lhs === rhs
    }
  }
}
