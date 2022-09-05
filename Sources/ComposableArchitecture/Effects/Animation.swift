import Combine
import SwiftUI

extension Effect {
  /// Wraps the emission of each element with SwiftUI's `withAnimation`.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return .task {
  ///     .activityResponse(await environment.apiClient.fetchActivity())
  ///   }
  ///   .animation()
  /// ```
  ///
  /// - Parameter animation: An animation.
  /// - Returns: A publisher.
  public func animation(_ animation: Animation? = .default) -> Self {
    switch self.operation {
    case .none:
      return .none
    case let .publisher(publisher):
      return Self(
        operation: .publisher(
          AnimatedPublisher(upstream: publisher, animation: animation).eraseToAnyPublisher()
        )
      )
    case let .run(priority, operation):
      return Self(
        operation: .run(priority) { send in
          await operation(
            Send { value in
              withAnimation(animation) {
                send(value)
              }
            }
          )
        }
      )
    }
  }
}

private struct AnimatedPublisher<Upstream: Publisher>: Publisher {
  typealias Output = Upstream.Output
  typealias Failure = Upstream.Failure

  var upstream: Upstream
  var animation: Animation?

  func receive<S: Combine.Subscriber>(subscriber: S)
  where S.Input == Output, S.Failure == Failure {
    let conduit = Subscriber(downstream: subscriber, animation: self.animation)
    self.upstream.receive(subscriber: conduit)
  }

  private class Subscriber<Downstream: Combine.Subscriber>: Combine.Subscriber {
    typealias Input = Downstream.Input
    typealias Failure = Downstream.Failure

    let downstream: Downstream
    let animation: Animation?

    init(downstream: Downstream, animation: Animation?) {
      self.downstream = downstream
      self.animation = animation
    }

    func receive(subscription: Subscription) {
      self.downstream.receive(subscription: subscription)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
      withAnimation(self.animation) {
        self.downstream.receive(input)
      }
    }

    func receive(completion: Subscribers.Completion<Failure>) {
      self.downstream.receive(completion: completion)
    }
  }
}
