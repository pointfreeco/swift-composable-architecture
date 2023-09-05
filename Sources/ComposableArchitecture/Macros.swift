#if swift(>=5.9)
  @attached(member, names: named(send))
  public macro WithViewStore<R: Reducer>(for: R.Type) = #externalMacro(
    module: "ComposableArchitectureMacros", type: "WithViewStoreMacro"
  ) where R.Action: ViewAction

  public protocol ViewAction<ViewAction> {
    associatedtype ViewAction
    static func view(_ action: ViewAction) -> Self
  }
#endif
