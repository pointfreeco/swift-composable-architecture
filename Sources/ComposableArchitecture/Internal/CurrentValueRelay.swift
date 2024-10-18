import Combine
import Foundation

final class CurrentValueRelay<Output>: Publisher {
  typealias Failure = Never

  private var currentValue: Output
  private let lock: NSLock
  private var subscriptions = ContiguousArray<Subscription>()

  var value: Output {
    get { self.lock.withLock { self.currentValue } }
    set { self.send(newValue) }
  }

  init(_ value: Output) {
    self.currentValue = value
    self.lock = NSLock()
  }

  func receive(subscriber: some Subscriber<Output, Never>) {
    let subscription = Subscription(upstream: self, downstream: subscriber)
    self.lock.withLock {
      self.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }

  func send(_ value: Output) {
    self.lock.withLock {
      self.currentValue = value
    }
    for subscription in self.lock.withLock({ self.subscriptions }) {
      subscription.receive(value)
    }
  }

  private func _remove(_ subscription: Subscription) {
    guard let index = self.subscriptions.firstIndex(of: subscription)
    else { return }
    self.subscriptions.remove(at: index)
  }

  private func remove(_ subscription: Subscription) {
    self.lock.withLock {
      self._remove(subscription)
    }
  }
}

extension CurrentValueRelay {
  fileprivate final class Subscription: Combine.Subscription, Equatable {
    private var _demand = Subscribers.Demand.none

    private var _downstream: (any Subscriber<Output, Never>)?
    var downstream: (any Subscriber<Output, Never>)? {
      var downstream: (any Subscriber<Output, Never>)?
      self.lock.withLock { downstream = _downstream }
      return downstream
    }

    private let lock: NSLock
    private var receivedLastValue = false
    private var upstream: CurrentValueRelay?

    init(upstream: CurrentValueRelay, downstream: any Subscriber<Output, Never>) {
      self.upstream = upstream
      self._downstream = downstream
      self.lock = upstream.lock
    }

    func cancel() {
      self.lock.withLock {
        self._downstream = nil
        self.upstream?._remove(self)
        self.upstream = nil
      }
    }

    func receive(_ value: Output) {
      guard let downstream else { return }

      self.lock.lock()
      switch self._demand {
      case .unlimited:
        self.lock.unlock()
        // NB: Adding to unlimited demand has no effect and can be ignored.
        _ = downstream.receive(value)

      case .none:
        self.receivedLastValue = false
        self.lock.unlock()

      default:
        self.receivedLastValue = true
        self._demand -= 1
        self.lock.unlock()
        let moreDemand = downstream.receive(value)
        self.lock.withLock {
          self._demand += moreDemand
        }
      }
    }

    func request(_ demand: Subscribers.Demand) {
      precondition(demand > 0, "Demand must be greater than zero")

      guard let downstream else { return }

      self.lock.lock()
      self._demand += demand

      guard
        !self.receivedLastValue,
        let value = self.upstream?.currentValue
      else {
        self.lock.unlock()
        return
      }

      self.receivedLastValue = true

      switch self._demand {
      case .unlimited:
        self.lock.unlock()
        // NB: Adding to unlimited demand has no effect and can be ignored.
        _ = downstream.receive(value)

      default:
        self._demand -= 1
        self.lock.unlock()
        let moreDemand = downstream.receive(value)
        self.lock.lock()
        self._demand += moreDemand
        self.lock.unlock()
      }
    }

    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
      lhs === rhs
    }
  }
}
