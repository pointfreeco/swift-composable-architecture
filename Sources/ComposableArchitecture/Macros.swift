import Observation

@freestanding(expression)
public macro feature<State, Action, ChildState, ChildAction>(
  _ keyPath: KeyPath<State, ChildState>
) -> Feature<State, Action, ChildState, ChildAction> = #externalMacro(
  module: "ComposableArchitectureMacros", type: "FeatureMacro"
)

@attached(member, names: named(_$id), named(_$observationRegistrar), named(access), named(withMutation))
@attached(memberAttribute)
@attached(extension, conformances: Observable, ObservableState)
public macro ObservableState() =
#externalMacro(module: "ComposableArchitectureMacros", type: "ObservableStateMacro")

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(_))
public macro ObservationStateTracked() =
#externalMacro(module: "ComposableArchitectureMacros", type: "ObservationStateTrackedMacro")

@attached(accessor, names: named(willSet))
public macro ObservationStateIgnored() =
#externalMacro(module: "ComposableArchitectureMacros", type: "ObservationStateIgnoredMacro")

@attached(member, names: named(send))
public macro WithViewStore<R: Reducer>(for: R.Type) = #externalMacro(
  module: "ComposableArchitectureMacros", type: "WithViewStoreMacro"
) where R.Action: ViewAction

public protocol ViewAction<ViewAction> {
  associatedtype ViewAction
  static func view(_ action: ViewAction) -> Self
  var view: ViewAction? { get }
}
