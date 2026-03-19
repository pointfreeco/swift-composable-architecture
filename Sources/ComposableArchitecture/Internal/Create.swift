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

@preconcurrency import Combine
import Foundation

final class DemandBuffer<S: Subscriber>: @unchecked Sendable {
  private var buffer = [S.Input]()
  private let subscriber: S
  private var completion: Subscribers.Completion<S.Failure>?
  private var demandState = Demand()
  private let lock = NSRecursiveLock()

  init(subscriber: S) {
    self.subscriber = subscriber
  }

  func buffer(value: S.Input) -> Subscribers.Demand {
    lock.lock()
    defer { lock.unlock() }

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
    lock.lock()
    defer { lock.unlock() }

    precondition(
      self.completion == nil, "Completion have already occurred, which is quite awkward 🥺")

    self.completion = completion
    _ = flush()
  }

  func demand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
    flush(adding: demand)
  }

  private func flush(adding newDemand: Subscribers.Demand? = nil) -> Subscribers.Demand {
    self.lock.sync {

      if let newDemand = newDemand {
        demandState.requested += newDemand
      }

      // If buffer isn't ready for flushing, return immediately
      guard demandState.requested > 0 || newDemand == Subscribers.Demand.none else { return .none }

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
  }

  struct Demand {
    var processed: Subscribers.Demand = .none
    var requested: Subscribers.Demand = .none
    var sent: Subscribers.Demand = .none
  }
}

extension AnyPublisher where Failure == Never {
  private init(
    _ callback: @escaping @Sendable (Effect<Output>.Subscriber) -> any Cancellable
  ) {
    self = Publishers.Create(callback: callback).eraseToAnyPublisher()
  }

  static func create(
    _ factory: @escaping @Sendable (Effect<Output>.Subscriber) -> any Cancellable
  ) -> AnyPublisher<Output, Failure> {
    AnyPublisher(factory)
  }
}

extension Publishers {
  fileprivate final class Create<Output>: Publisher, Sendable {
    typealias Failure = Never

    private let callback: @Sendable (Effect<Output>.Subscriber) -> any Cancellable

    init(callback: @escaping @Sendable (Effect<Output>.Subscriber) -> any Cancellable) {
      self.callback = callback
    }

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
      subscriber.receive(subscription: Subscription(callback: callback, downstream: subscriber))
    }
  }
}

extension Publishers.Create {
  fileprivate final class Subscription<Downstream: Subscriber>: Combine.Subscription, Sendable
  where Downstream.Input == Output, Downstream.Failure == Never {
    private let buffer: DemandBuffer<Downstream>
    private let cancellable = LockIsolated<(any Cancellable)?>(nil)

    init(
      callback: @escaping @Sendable (Effect<Output>.Subscriber) -> any Cancellable,
      downstream: Downstream
    ) {
      self.buffer = DemandBuffer(subscriber: downstream)

      self.cancellable.setValue(
        callback(
          .init(
            send: { [weak self] in _ = self?.buffer.buffer(value: $0) },
            complete: { [weak self] in self?.buffer.complete(completion: $0) }
          )
        )
      )
    }

    func request(_ demand: Subscribers.Demand) {
      _ = self.buffer.demand(demand)
    }

    func cancel() {
      self.cancellable.value?.cancel()
    }
  }
}

extension Publishers.Create.Subscription: CustomStringConvertible {
  var description: String {
    return "Create.Subscription<\(Output.self)>"
  }
}

extension Effect {
  struct Subscriber: Sendable {
    private let _send: @Sendable (Action) -> Void
    private let _complete: @Sendable (Subscribers.Completion<Never>) -> Void

    init(
      send: @escaping @Sendable (Action) -> Void,
      complete: @escaping @Sendable (Subscribers.Completion<Never>) -> Void
    ) {
      self._send = send
      self._complete = complete
    }

    public func send(_ value: Action) {
      self._send(value)
    }

    public func send(completion: Subscribers.Completion<Never>) {
      self._complete(completion)
    }
  }
}
