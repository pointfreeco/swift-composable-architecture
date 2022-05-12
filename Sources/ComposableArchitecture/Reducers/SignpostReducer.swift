import OSLog

extension ReducerProtocol {
  @inlinable
  public func signpost(
    _ prefix: String = "",
    log: OSLog = OSLog(
      subsystem: "co.pointfree.ComposableArchitecture",
      category: "Reducer Instrumentation"
    )
  ) -> SignpostReducer<Self> {
    .init(
      upstream: self,
      prefix: prefix,
      log: log
    )
  }
}

public struct SignpostReducer<Upstream>: ReducerProtocol
where Upstream: ReducerProtocol {
  public let upstream: Upstream

  @usableFromInline
  let prefix: String

  @usableFromInline
  let log: OSLog

  @usableFromInline
  init(
    upstream: Upstream,
    prefix: String,
    log: OSLog
  ) {
    self.upstream = upstream
    // NB: Prevent rendering as "N/A" in Instruments
    let zeroWidthSpace = "\u{200B}"
    self.prefix = prefix.isEmpty ? zeroWidthSpace : "[\(prefix)] "
    self.log = log
  }

  @inlinable
  public func reduce(
    into state: inout Upstream.State,
    action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    var actionOutput: String!
    if self.log.signpostsEnabled {
      actionOutput = debugCaseOutput(action)
      os_signpost(.begin, log: log, name: "Action", "%s%s", self.prefix, actionOutput)
    }
    let effects = self.upstream.reduce(into: &state, action: action)
    if self.log.signpostsEnabled {
      os_signpost(.end, log: self.log, name: "Action")
      return effects
        .effectSignpost(self.prefix, log: self.log, actionOutput: actionOutput)
        .eraseToEffect()
    }
    return effects
  }
}
