import Combine

// Credit: https://blog.human-friendly.com/asyncsequence--combine-equivalence-part-1

// AsyncSequence -> Publisher
@available(iOS 15.0, macOS 12.0, *)
public struct AsyncSequencePublisher<AsyncSequenceType> : Publisher where AsyncSequenceType : AsyncSequence {
  public typealias Output = AsyncSequenceType.Element
  public typealias Failure = Error

  let sequence: AsyncSequenceType

  public init(_ sequence: AsyncSequenceType) {
    self.sequence = sequence
  }

  fileprivate class ASPSubscription<S> : Subscription
  where S : Subscriber, S.Failure == Error, S.Input == AsyncSequenceType.Element {
    private var taskHandle: Task<(), Never>?
    private let innerActor = Inner()

    /// Ideally this wouldn't be needed and the ASPSubscriber could be an actor itself but due to issues in Xcode 13 beta 1 and 2
    /// continuations can't safely be resumed from actor contexts so this separate actor is needed to manage the demand and th
    /// continuation but to return it instead of resuming it directly. The callers of `add(demand:)` and
    /// `getContinuationToFireOnCancelation` shoudl always resume the returned value immediately
    private actor Inner {
      var demand: Subscribers.Demand = .none
      var demandUpdatedContinuation: CheckedContinuation<Void, Never>?

      /// Returns immediately if there is demand for an additional item from the subscriber or awaits an increase in demand
      /// then will return when there is some demand (or the task has been cancelled and the continuation fired)
      fileprivate func waitUntilReadyForMore() async {
        if demand > 0 {
          demand -= 1
          return
        }

        let _: Void = await withCheckedContinuation { continuation in
          demandUpdatedContinuation = continuation
        }
      }

      /// Update the tracked demand for the publisher
      /// - Parameter demand: The additional demand for the publisher
      /// - Returns: A continuation that must be resumed off the actor context immediatly
      func add(demand: Subscribers.Demand) -> CheckedContinuation<Void, Never>? {
        defer { demandUpdatedContinuation = nil }
        self.demand += demand
        guard demand > 0 else { return nil }
        return demandUpdatedContinuation
      }


      /// This is used to prevent being permanently stuck awaiting the continuation if the task has been cancelled
      /// - Returns: Continuation to resume to allow cancellation to complete
      func getContinuationToFireOnCancelation()  -> CheckedContinuation<Void, Never>? {
        defer { demandUpdatedContinuation = nil }
        return demandUpdatedContinuation
      }
    }

    /// Kicks off the main loop over the async sequence. Does the main work within the for loop over the async seqence
    /// - Parameters:
    ///   - seq: The AsyncSequence that is the source
    ///   - sub: The Subscriber to this Subscription
    private func mainLoop(seq: AsyncSequenceType, sub: S) {
      // taskHandle is kept for cancelation
      taskHandle = Task {
        do {
          try await withTaskCancellationHandler {
            Task.detached {
              let cont = await self.innerActor.getContinuationToFireOnCancelation()
              cont?.resume()
            }
          } operation: {
            for try await element in seq {
              // Check for demand before providing the first item
              await self.innerActor.waitUntilReadyForMore()

              try Task.checkCancellation()
//              guard !Task.isCancelled else { return } // Exit if cancelled

              let newDemand = sub.receive(element) // Pass on the item
              let cont = await self.innerActor.add(demand: newDemand)
              assert(cont == nil,
                     "If we are't waiting on the demand the continuation will always be nil")
              // cont should always be nil as it will only be set when this loop is
              // waiting on demand
              cont?.resume()

            }
            // Finished the AsyncSequence so finish the subcription
            sub.receive(completion: .finished)
            return
          }
        } catch {
          // Cancel means the subscriber shouldn't get more, even errors so exit
          if error is CancellationError { return }
          sub.receive(completion: .failure(error))
        }
      }
    }

    init(sequence: AsyncSequenceType, subscriber: S) {
      self.mainLoop(seq: sequence, sub: subscriber)
    }

    func request(_ demand: Subscribers.Demand) {
      Task {
        let cont = await innerActor.add(demand: demand)
        cont?.resume()
      }
    }

    func cancel() {
      // Part of the Cancellable / Publisher API - Stop the main loop
      taskHandle?.cancel()
    }

    deinit {
      cancel()
    }
  }

  public func receive<S>(subscriber: S)
  where S : Subscriber, Error == S.Failure, AsyncSequenceType.Element == S.Input {
    let subscription = ASPSubscription(sequence: sequence, subscriber: subscriber)
    subscriber.receive(subscription: subscription)
  }
}

@available(iOS 15.0, macOS 12.0, *)
extension AsyncSequence {
  ///  Returns a Combine publisher for the sequence - Not recomended for production. Structured Concurrency demonstration
  ///  not performance tested
  public var publisher: AsyncSequencePublisher<Self> {
    AsyncSequencePublisher(self)
  }
}
