import Combine
import SwiftUI

@propertyWrapper
public struct ObservedViewStore<State, Action>: DynamicProperty {
  public init(wrappedValue viewStore: ViewStore<State, Action>) {
    self._wrappedValue = .init(wrappedValue: viewStore)
    viewStore.observedViewStore = self
  }

  @ObservedObject public var wrappedValue: ViewStore<State, Action>

  public var projectedValue: ObservedObject<ViewStore<State, Action>>.Wrapper {
    $wrappedValue
  }

  func projectedBinding<Value>(for keyPath: WritableKeyPath<State, BindableState<Value>>) -> Binding<Value> where Action: BindableAction, Action.State == State, Value: Equatable {
    return $wrappedValue[binding: keyPath]
  }
}

extension ViewStore  {
  func projectedBinding<Value>(for keyPath: WritableKeyPath<State, BindableState<Value>>) -> Binding<Value>? where Action: BindableAction, Action.State == State, Value: Equatable {
    self.observedViewStore?.projectedBinding(for: keyPath)
  }

  subscript<Value>(
    binding keyPath: WritableKeyPath<State, BindableState<Value>>
  ) -> Value
    where Action: BindableAction, Action.State == State, Value: Equatable
  {
    get { self.state[keyPath: keyPath].wrappedValue }
    set { self.send(.binding(.set(keyPath, newValue))) }
  }
}
