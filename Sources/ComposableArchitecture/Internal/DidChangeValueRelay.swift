import Combine
import Foundation

struct DidChangeValueRelay<Value>: Publisher {
	typealias Failure = Never
	typealias Output = (oldValue: Value?, newValue: Value)

	@RelayBinding private var source: Value
	@RelayBinding private var subscriptions: [Subscription<AnySubscriber<Output, Failure>>]

  var value: Value {
    get { source }
		nonmutating set { self.send(newValue, oldValue: source) }
  }

  init(_ value: Value) {
		_source = RelayBinding(value)
		_subscriptions = RelayBinding([])
  }

  func receive<S>(subscriber: S)
  where S: Subscriber, Never == S.Failure, Output == S.Input {
    let subscription = Subscription(downstream: AnySubscriber(subscriber))
    subscriber.receive(subscription: subscription)
    subscription.forwardValueToBuffer((nil, source))
		self.subscriptions.append(subscription)
  }
	
	func map<T>(get: @escaping (Value) -> T, set: @escaping (inout Value, T) -> Void) -> DidChangeValueRelay<T> {
		DidChangeValueRelay<T>(
			source: RelayBinding(
				get: {[_source] in
					get(_source.wrappedValue)
				},
				set: {[_source] in
					set(&_source.wrappedValue, $0)
				}
			),
			subscriptions: RelayBinding(
				get: { [] },
				set: {[_subscriptions] in
					_subscriptions.wrappedValue += $0.map {
						Subscription(
							demandBuffer: $0.demandBuffer?.map { subscriber in
								AnySubscriber(
									receiveSubscription: subscriber.receive(subscription:),
									receiveValue: { subscriber.receive(($0.oldValue.map(get), get($0.newValue))) },
									receiveCompletion: subscriber.receive(completion:)
								)
							} value: {[_source] in
								var newValue = _source.wrappedValue
								set(&newValue, $0.newValue)
								var oldValue = _source.wrappedValue
								$0.oldValue.map { set(&oldValue, $0) }
								return (oldValue, newValue)
							}
						)
					}
				}
			)
		)
	}

	private func send(_ value: Value, oldValue: Value?) {
		source = value
    for subscription in subscriptions {
      subscription.forwardValueToBuffer((oldValue, value))
    }
  }
	
	private init(source: RelayBinding<Value>, subscriptions: RelayBinding<[Subscription<AnySubscriber<Output, Failure>>]>) {
		self._source = source
		self._subscriptions = subscriptions
	}
}

extension DidChangeValueRelay {
	final class Subscription<Downstream: Subscriber>: Combine.Subscription
	where Output == Downstream.Input, Failure == Downstream.Failure {
    fileprivate var demandBuffer: DemandBuffer<Downstream>?

		convenience init(downstream: Downstream) {
			self.init(demandBuffer: DemandBuffer(downstream))
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
		
		fileprivate init(demandBuffer: DemandBuffer<Downstream>?) {
			self.demandBuffer = demandBuffer
		}
  }
}
