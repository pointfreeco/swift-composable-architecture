import Combine
import SwiftUI

extension Publisher {
  public func animation(_ animation: Animation? = .default) -> Effect<Output, Failure> {
    AnimatedPublisher(upstream: self, animation: animation)
      .eraseToEffect()
  }
}

private struct AnimatedPublisher<Upstream: Publisher>: Publisher {
  public typealias Output = Upstream.Output
  public typealias Failure = Upstream.Failure

  public var upstream: Upstream
  public var animation: Animation?

  public func receive<S>(subscriber: S) where S : Combine.Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
    let conduit = Subscriber(downstream: subscriber, animation: self.animation)
    upstream.receive(subscriber: conduit)
  }

  fileprivate class Subscriber<Downstream: Combine.Subscriber>: Combine.Subscriber {
    typealias Input = Downstream.Input
    typealias Failure = Downstream.Failure

    let downstream: Downstream
    let animation: Animation?

    init(downstream: Downstream, animation: Animation?) {
      self.downstream = downstream
      self.animation = animation
    }

    func receive(subscription: Subscription) {
      downstream.receive(subscription: subscription)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
      withAnimation(self.animation) {
        downstream.receive(input)
      }
    }

    func receive(completion: Subscribers.Completion<Failure>) {
      downstream.receive(completion: completion)
    }
  }
}
