#if canImport(UIKit) && !os(watchOS)
  import Combine
  import UIKitNavigation
  
  extension Effect {
    /// Wraps the emission of each element with `withUIKitAnimation`.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   return .run { send in
    ///     await send(.activityResponse(self.apiClient.fetchActivity()))
    ///   }
    ///   .uiKitAnimation()
    /// ```
    ///
    /// - Parameter animation: An animation.
    /// - Returns: A publisher.
    public func uiKitAnimation(_ animation: UIKitAnimation? = .default) -> Self {
      self.transaction(UITransaction(animation: animation))
    }
    
    /// Wraps the emission of each element with `withUITransaction`.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   var transaction = UITransaction(animation: .default)
    ///   transaction.uiKit.disablesAnimations = true
    ///   return .run { send in
    ///     await send(.activityResponse(self.apiClient.fetchActivity()))
    ///   }
    ///   .transaction(transaction)
    /// ```
    ///
    /// - Parameter transaction: A transaction.
    /// - Returns: A publisher.
    public func transaction(_ transaction: UITransaction) -> Self {
      switch self.operation {
      case .none:
        return .none
      case let .publisher(publisher):
        return Self(
          operation: .publisher(
            UITransactionPublisher(
              upstream: publisher,
              transaction: transaction
            )
            .eraseToAnyPublisher()
          )
        )
      case let .run(priority, operation):
        return Self(
          operation: .run(priority) { send in
            await operation(
              Send { value in
                withUITransaction(transaction) {
                  send(value)
                }
              }
            )
          }
        )
      }
    }
  }

  private struct UITransactionPublisher<Upstream: Publisher>: Publisher {
    typealias Output = Upstream.Output
    typealias Failure = Upstream.Failure
    
    var upstream: Upstream
    var transaction: UITransaction
    
    func receive(subscriber: some Combine.Subscriber<Upstream.Output, Upstream.Failure>) {
      let conduit = Subscriber(downstream: subscriber, transaction: self.transaction)
      self.upstream.receive(subscriber: conduit)
    }
    
    private final class Subscriber<Downstream: Combine.Subscriber>: Combine.Subscriber {
      typealias Input = Downstream.Input
      typealias Failure = Downstream.Failure
      
      let downstream: Downstream
      let transaction: UITransaction
      
      init(downstream: Downstream, transaction: UITransaction) {
        self.downstream = downstream
        self.transaction = transaction
      }
      
      func receive(subscription: Subscription) {
        self.downstream.receive(subscription: subscription)
      }
      
      func receive(_ input: Input) -> Subscribers.Demand {
        withUITransaction(self.transaction) {
          self.downstream.receive(input)
        }
      }
      
      func receive(completion: Subscribers.Completion<Failure>) {
        self.downstream.receive(completion: completion)
      }
    }
  }
#endif


