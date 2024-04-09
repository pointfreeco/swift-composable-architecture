#if canImport(Combine)
  // https://github.com/CombineCommunity/CombineExt/blob/master/Sources/Operators/Create.swift

  // Copyright (c) 2020 Combine Community, and/or Shai Mishali
  //
  // Permission is hereby granted, free of charge, to any person obtaining a copy
  // of this software and associated documentation files (the "Software"), to deal
  // in the Software without restriction, including without limitation the rights
  // to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  // copies of the Software, and to permit persons to whom the Software is
  // furnished to do so, subject to the following conditions:
  //
  // The above copyright notice and this permission notice shall be included in
  // all copies or substantial portions of the Software.
  //
  // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  // AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  // THE SOFTWARE.

  import Combine
  import Darwin

  final class DemandBuffer<S: Subscriber>: @unchecked Sendable {
    private var buffer = [S.Input]()
    private let subscriber: S
    private var completion: Subscribers.Completion<S.Failure>?
    private var demandState = Demand()
    private let lock: os_unfair_lock_t

    init(subscriber: S) {
      self.subscriber = subscriber
      self.lock = os_unfair_lock_t.allocate(capacity: 1)
      self.lock.initialize(to: os_unfair_lock())
    }

    deinit {
      self.lock.deinitialize(count: 1)
      self.lock.deallocate()
    }

    func buffer(value: S.Input) -> Subscribers.Demand {
      precondition(
        self.completion == nil, "How could a completed publisher sent values?! Beats me 🤷‍♂️")

      switch demandState.requested {
      case .unlimited:
        return subscriber.receive(value)
      default:
        buffer.append(value)
        return flush()
      }
    }

    func complete(completion: Subscribers.Completion<S.Failure>) {
      precondition(
        self.completion == nil, "Completion have already occurred, which is quite awkward 🥺")

      self.completion = completion
      _ = flush()
    }

    func demand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
      flush(adding: demand)
    }

    private func flush(adding newDemand: Subscribers.Demand? = nil) -> Subscribers.Demand {
      os_unfair_lock_lock(self.lock)
      defer { os_unfair_lock_unlock(self.lock) }

      if let newDemand = newDemand {
        demandState.requested += newDemand
      }

      // If buffer isn't ready for flushing, return immediately
      guard demandState.requested > 0 || newDemand == Subscribers.Demand.none else {
        return .none
      }

      while !buffer.isEmpty && demandState.processed < demandState.requested {
        demandState.requested += subscriber.receive(buffer.remove(at: 0))
        demandState.processed += 1
      }

      if let completion = completion {
        // Completion event was already sent
        buffer = []
        demandState = .init()
        self.completion = nil
        subscriber.receive(completion: completion)
        return .none
      }

      let sentDemand = demandState.requested - demandState.sent
      demandState.sent += sentDemand
      return sentDemand
    }

    struct Demand {
      var processed: Subscribers.Demand = .none
      var requested: Subscribers.Demand = .none
      var sent: Subscribers.Demand = .none
    }
  }
#endif
