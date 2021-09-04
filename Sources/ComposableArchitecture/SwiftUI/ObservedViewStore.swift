import Combine
import SwiftUI

@propertyWrapper
public struct ObservedViewStore<State, Action>: DynamicProperty {
  @ObservedObject public var wrappedValue: ViewStore<State, Action>

  public init(wrappedValue viewStore: ViewStore<State, Action>) {
    self.wrappedValue = viewStore
    viewStore.observedViewStore = self
  }

  public var projectedValue: ObservedObject<ViewStore<State, Action>>.Wrapper {
    self.$wrappedValue
  }

  fileprivate func projectedBinding<Value>(
    for keyPath: WritableKeyPath<State, BindableState<Value>>
  ) -> Binding<Value>
    where Action: BindableAction, Action.State == State, Value: Equatable
  {
    self.$wrappedValue[bindable: keyPath]
  }
}

extension ViewStore {
  func projectedBinding<Value>(
    for keyPath: WritableKeyPath<State, BindableState<Value>>
  ) -> Binding<Value>?
    where Action: BindableAction, Action.State == State, Value: Equatable
  {
    self.observedViewStore?.projectedBinding(for: keyPath)
  }

  subscript<Value>(
    bindable keyPath: WritableKeyPath<State, BindableState<Value>>
  ) -> Value
    where Action: BindableAction, Action.State == State, Value: Equatable
  {
    get { self.state[keyPath: keyPath].wrappedValue }
    set { self.send(.binding(.set(keyPath, newValue))) }
  }
}
