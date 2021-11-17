import Combine
import Foundation

final class DidChangeValueRelay<Value>: Publisher {
	typealias Failure = Never
	typealias Output = (oldValue: Value?, newValue: Value)

	@RelayBinding private var source: Value
	private var subscriptions: [RelaySubscription<AnySubscriber<Output, Failure>>] = []
	private var _receive: (AnySubscriber<Output, Never>) -> Void = { _ in }

  var value: Value {
    get { source }
		set { self.send(newValue, oldValue: source) }
  }

  init(_ value: Value) {
		_source = RelayBinding(value)
		_receive = {[weak self] in
			let subscription = RelaySubscription(downstream: $0)
			$0.receive(subscription: subscription)
			self?.subscriptions.append(subscription)
		}
  }

  func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
		_receive(AnySubscriber(subscriber))
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
			receive: {[_receive] subscriber in
				_receive(
					AnySubscriber(
						receiveSubscription: { subscriber.receive(subscription: $0) },
						receiveValue: { subscriber.receive(($0.map(get), get($1))) },
						receiveCompletion: { subscriber.receive(completion: $0) }
					)
				)
			}
		)
	}

	private func send(_ value: Value, oldValue: Value?) {
		source = value
    for subscription in subscriptions {
      subscription.forwardValueToBuffer((oldValue, value))
    }
  }
	
	private init(source: RelayBinding<Value>, receive: @escaping (AnySubscriber<Output, Never>) -> Void) {
		self._source = source
		self._receive = receive
	}
}
