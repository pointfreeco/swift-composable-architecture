//
//  File.swift
//  
//
//  Created by Данил Войдилов on 17.11.2021.
//

import Combine
import AppKit

final class RemoveDublicatesRelay<Value>: Publisher {
	typealias Failure = Never
	typealias Output = DidChangeValueRelay<Value>.Output
	
	let relay: DidChangeValueRelay<Value>
	let isDuplicate: (Value, Value) -> Bool
	var value: Value { relay.value }
	private var subscriptions: [RelaySubscription<AnySubscriber<Output, Failure>>] = []
	private var bag = Set<AnyCancellable>()
	
	init(relay: DidChangeValueRelay<Value>, isDuplicate: @escaping (Value, Value) -> Bool) {
		self.relay = relay
		self.isDuplicate = isDuplicate
		
		relay.sink {[weak self] value in
			if let oldValue = value.oldValue, isDuplicate(oldValue, value.newValue) { return }
			self?.subscriptions.forEach { $0.forwardValueToBuffer(value) }
		}.store(in: &bag)
	}
	
	func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Output == S.Input {
		let subscription = RelaySubscription(downstream: AnySubscriber(subscriber))
		subscriber.receive(subscription: subscription)
		subscription.forwardValueToBuffer((nil, value))
		self.subscriptions.append(subscription)
	}
}
