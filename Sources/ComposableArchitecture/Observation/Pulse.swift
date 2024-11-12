//
//  Pulse.swift
//  swift-composable-architecture
//
//  Created by Jaewook Hwang on 11/13/24.
//

import Foundation
import Combine

/**
 * Example - Reducer
 **
```swift
@Reducer
struct Feature {
    @ObservableState
    struct State {
        var errorMessage: Pulse<String?> = .init(wrappedValue: nil)
        // Other properties
 
    }
   enum Action { /* ... */ }

   var body: some Reducer<State, Action> {
     Reduce { state, action in
       switch action {
       case .setErrorMessage(let errorMessage):
         state.errorMessage.value = errorMessage
         return .none
       }
     }
   }
}
```
 **
 * Example - store publisher
 **
 ```swift
 
 store.publisher.pulse(\.errorMessage)
    .compactMap { $0 }
    .sink { [weak self] errorMessage in
       // error message alert or something
    }
    .store(in: &cancellable)
 ```
 */

/// > Note: This Pulse is from ReactorKit made by Tokijh
/// https://github.com/ReactorKit/ReactorKit?tab=readme-ov-file#pulse
/// It is useful for optimizing observation of state. Because Pulse has
/// ``valueUpdatedCount`` value, we can filter the state stream whenever
/// the real value is assigned in a Reducer.
/// so it is helpful to avoid unexpected state-changing stream and
/// just to get the value whenever the state of real value is assigned
public struct Pulse<Value: Equatable>: Equatable {
  public var value: Value {
    didSet {
      raiseValueUpdatedCount()
    }
  }
  
  public internal(set) var valueUpdatedCount = UInt.min
  
  public init(wrappedValue: Value) {
    value = wrappedValue
  }
  
  public var projectedValue: Pulse<Value> {
    self
  }
  
  private mutating func raiseValueUpdatedCount() {
    if valueUpdatedCount == UInt.max {
      valueUpdatedCount = UInt.min
    } else {
      valueUpdatedCount += 1
    }
  }
}

/// This function is for using Pulse with Store in a more convenient way.
/// With this extension function, we can the get the stream of value whenever the state of real value is assigned.
extension StorePublisher {
  public func pulse<Value>(_ keyPath: KeyPath<State, Pulse<Value>>) -> AnyPublisher<Value, Never> {
    map { state in
      state[keyPath: keyPath]
    }
    .removeDuplicates(by: { oldPulse, newPulse in
      oldPulse.valueUpdatedCount == newPulse.valueUpdatedCount
    })
    .map { pulse in
      pulse.value
    }
    .eraseToAnyPublisher()
  }
}
