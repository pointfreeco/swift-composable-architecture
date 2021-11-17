//
//  File.swift
//  
//
//  Created by Данил Войдилов on 17.11.2021.
//

import Foundation

@propertyWrapper
struct RelayBinding<Value> {
	
	var wrappedValue: Value {
		get { get() }
		nonmutating set { set(newValue) }
	}
	
	var get: () -> Value
	var set: (Value) -> Void
	
	init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
		self.get = get
		self.set = set
	}
	
	init(_ value: Value) {
		var value = value
		self.init {
			value
		} set: {
			value = $0
		}
	}
	
	init(wrappedValue: Value) {
		self.init(wrappedValue)
	}
}
