#if swift(>=5.9)
  import Observation

  @attached(member, names: named(send))
  public macro WithViewStore<R: Reducer>(for: R.Type) = #externalMacro(
    module: "ComposableArchitectureMacros", type: "WithViewStoreMacro"
  ) where R.Action: ViewAction

  public protocol ViewAction<ViewAction> {
    associatedtype ViewAction
    static func view(_ action: ViewAction) -> Self
  }

  @attached(member, names: named(_$id), named(_$observationRegistrar), named(access), named(withMutation))
  @attached(memberAttribute)
  @attached(extension, conformances: Observable, ObservableState)
  public macro ObservableState() =
  #externalMacro(module: "ComposableArchitectureMacros", type: "ObservableStateMacro")
#endif
