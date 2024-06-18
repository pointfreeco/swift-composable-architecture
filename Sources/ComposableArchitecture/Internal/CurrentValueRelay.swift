import Combine
import Foundation

final class CurrentValueRelay<Output>: Publisher {
  typealias Failure = Never

  private var currentValue: Output
  private var subscriptions: [Subscription<AnySubscriber<Output, Failure>>] = []

  var value: Output {
    get { self.currentValue }
    set { self.send(newValue) }
  }

  init(_ value: Output) {
    self.currentValue = value
  }

  func receive(subscriber: some Subscriber<Output, Never>) {
    let subscription = Subscription(downstream: AnySubscriber(subscriber))
    self.subscriptions.append(subscription)
    subscriber.receive(subscription: subscription)
    subscription.forwardValueToBuffer(self.currentValue)
  }

  func send(_ value: Output) {
    self.currentValue = value
    for subscription in subscriptions {
      subscription.forwardValueToBuffer(value)
    }
  }
}

extension CurrentValueRelay {
  final class Subscription<Downstream: Subscriber<Output, Failure>>: Combine.Subscription {
    private var demandBuffer: DemandBuffer<Downstream>?

    init(downstream: Downstream) {
      self.demandBuffer = DemandBuffer(subscriber: downstream)
    }

    func forwardValueToBuffer(_ value: Output) {
      _ = demandBuffer?.buffer(value: value)
    }

    func request(_ demand: Subscribers.Demand) {
      _ = demandBuffer?.demand(demand)
    }

    func cancel() {
      demandBuffer = nil
    }
  }
}
