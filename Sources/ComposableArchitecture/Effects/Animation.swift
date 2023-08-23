#if canImport(SwiftUI)
  import Combine
  import SwiftUI

  extension Effect {
    /// Wraps the emission of each element with SwiftUI's `withAnimation`.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   return .run { send in
    ///     await send(.activityResponse(self.apiClient.fetchActivity()))
    ///   }
    ///   .animation()
    /// ```
    ///
    /// - Parameter animation: An animation.
    /// - Returns: A publisher.
    public func animation(_ animation: Animation? = .default) -> Self {
      self.transaction(Transaction(animation: animation))
    }

    /// Wraps the emission of each element with SwiftUI's `withTransaction`.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   var transaction = Transaction(animation: .default)
    ///   transaction.disablesAnimations = true
    ///   return .run { send in
    ///     await send(.activityResponse(self.apiClient.fetchActivity()))
    ///   }
    ///   .transaction(transaction)
    /// ```
    ///
    /// - Parameter transaction: A transaction.
    /// - Returns: A publisher.
    public func transaction(_ transaction: Transaction) -> Self {
      self
//      .init(
//        operation: .init(
//          sync: self.operation.sync.map { sync in
//            { send in
//              sync(Send<Action>.Continuation { action in
//                withTransaction(transaction) {
//                  send(action)
//                }
//              })
//            }
//          },
//          async: self.operation.async.map { priority, operation in
//            (priority, { send in
//              await operation(
//                Send { value in
//                  withTransaction(transaction) {
//                    send(value)
//                  }
//                }
//              )
//            })
//          }
//        )
//      )
    }
  }

  private struct TransactionPublisher<Upstream: Publisher>: Publisher {
    typealias Output = Upstream.Output
    typealias Failure = Upstream.Failure

    var upstream: Upstream
    var transaction: Transaction

    func receive<S: Combine.Subscriber>(subscriber: S)
    where S.Input == Output, S.Failure == Failure {
      let conduit = Subscriber(downstream: subscriber, transaction: self.transaction)
      self.upstream.receive(subscriber: conduit)
    }

    private final class Subscriber<Downstream: Combine.Subscriber>: Combine.Subscriber {
      typealias Input = Downstream.Input
      typealias Failure = Downstream.Failure

      let downstream: Downstream
      let transaction: Transaction

      init(downstream: Downstream, transaction: Transaction) {
        self.downstream = downstream
        self.transaction = transaction
      }

      func receive(subscription: Subscription) {
        self.downstream.receive(subscription: subscription)
      }

      func receive(_ input: Input) -> Subscribers.Demand {
        withTransaction(self.transaction) {
          self.downstream.receive(input)
        }
      }

      func receive(completion: Subscribers.Completion<Failure>) {
        self.downstream.receive(completion: completion)
      }
    }
  }
#endif
