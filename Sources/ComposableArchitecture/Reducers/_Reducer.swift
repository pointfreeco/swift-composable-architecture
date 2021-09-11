public protocol _Reducer {
  associatedtype State
  associatedtype Action

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never>
}

// store.environment(\.apiClient.endpoint) { _ in Effect(value: .success(1)) } <-
// reducer.environment(\.apiClient.endpoint) { _ in Effect(value: .success(1)) }

// @Dependency
// @EnvironmentDependecy

// dependencies as actors
// @MainActor class Store

// TODO: ReducerModifier??
