#if swift(>=5.9)
  @attached(memberAttribute)
  @attached(extension, conformances: Reducer)
  public macro Reducer() = #externalMacro(
    module: "ComposableArchitectureMacros", type: "ReducerMacro"
  )
#endif
