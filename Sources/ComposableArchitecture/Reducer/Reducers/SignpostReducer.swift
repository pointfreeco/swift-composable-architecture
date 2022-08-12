import OSLog

extension ReducerProtocol {
  @inlinable
  public func signpost(
    _ prefix: String = "",
    // TODO: Move log to `DependencyValues`?
    log: OSLog = OSLog(
      subsystem: "co.pointfree.ComposableArchitecture",
      category: "Reducer Instrumentation"
    )
  ) -> _SignpostReducer<Self> {
    _SignpostReducer(base: self, prefix: prefix, log: log)
  }
}

public struct _SignpostReducer<Base: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let base: Base

  @usableFromInline
  let prefix: String

  @usableFromInline
  let log: OSLog

  @usableFromInline
  init(
    base: Base,
    prefix: String,
    log: OSLog
  ) {
    self.base = base
    // NB: Prevent rendering as "N/A" in Instruments
    let zeroWidthSpace = "\u{200B}"
    self.prefix = prefix.isEmpty ? zeroWidthSpace : "[\(prefix)] "
    self.log = log
  }

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> Effect<Base.Action, Never> {
    var actionOutput: String!
    if self.log.signpostsEnabled {
      actionOutput = debugCaseOutput(action)
      os_signpost(.begin, log: log, name: "Action", "%s%s", self.prefix, actionOutput)
    }
    let effects = self.base.reduce(into: &state, action: action)
    if self.log.signpostsEnabled {
      os_signpost(.end, log: self.log, name: "Action")
      return
        effects
        .effectSignpost(self.prefix, log: self.log, actionOutput: actionOutput)
        .eraseToEffect()
    }
    return effects
  }
}
