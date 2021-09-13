public protocol _Reducer {
  associatedtype State
  associatedtype Action

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never>
}

// TODO: ReducerModifier??
