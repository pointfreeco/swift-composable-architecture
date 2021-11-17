//
//  File.swift
//  
//
//  Created by Данил Войдилов on 17.11.2021.
//

import Combine

struct RemoveDublicatesRelay<Output>: Publisher {
	typealias Failure = Never
	
	let relay: DidChangeValueRelay<Output>
	let isDuplicate: (Output, Output) -> Bool
	var value: Output { relay.value }
	
	func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Output == S.Input {
		relay.compactMap {[isDuplicate] in
			if let oldValue = $0, isDuplicate(oldValue, $1) { return nil }
			return $1
		}.subscribe(subscriber)
	}
}
