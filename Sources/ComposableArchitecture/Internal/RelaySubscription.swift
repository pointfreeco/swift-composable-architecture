//
//  File.swift
//  
//
//  Created by Данил Войдилов on 17.11.2021.
//

import Combine

final class RelaySubscription<Downstream: Subscriber>: Subscription {
	var demandBuffer: DemandBuffer<Downstream>?
	
	init(downstream: Downstream) {
		demandBuffer = DemandBuffer(subscriber: downstream)
	}
	
	func forwardValueToBuffer(_ value: Downstream.Input) {
		_ = demandBuffer?.buffer(value: value)
	}
	
	func request(_ demand: Subscribers.Demand) {
		_ = demandBuffer?.demand(demand)
	}
	
	func cancel() {
		demandBuffer = nil
	}
}
