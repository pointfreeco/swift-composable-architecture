import SwiftUI

@available(iOS, deprecated: 17, message: "TODO")
@available(macOS, deprecated: 14, message: "TODO")
@available(tvOS, deprecated: 17, message: "TODO")
@available(watchOS, deprecated: 10, message: "TODO")
@propertyWrapper
public struct BindableStore<State, Action> {
  public let wrappedValue: Store<State, Action>
  public init(wrappedValue: Store<State, Action>) {
    self.wrappedValue = wrappedValue
  }

  public var projectedValue: Binding<Store<State, Action>> {
    Binding(
      get: { self.wrappedValue },
      set: { _ in }  // TODO: Should this technically allow assignment?
    )
  }
}
