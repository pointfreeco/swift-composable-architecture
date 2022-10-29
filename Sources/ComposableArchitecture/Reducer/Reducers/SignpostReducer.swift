import OSLog

extension ReducerProtocol {
  /// Instruments a reducer with
  /// [signposts](https://developer.apple.com/documentation/os/logging/recording_performance_data).
  ///
  /// Each invocation of the reducer will be measured by an interval, and the lifecycle of its
  /// effects will be measured with interval and event signposts.
  ///
  /// To use, build your app for profiling, create a blank instrument, and add the signpost
  /// instrument. Start recording your app you will see timing information for every action sent to
  /// the store, as well as every effect executed.
  ///
  /// Effect instrumentation can be particularly useful for inspecting the lifecycle of long-living
  /// effects. For example, if you start an effect (_e.g._, a location manager) in `onAppear` and
  /// forget to tear down the effect in `onDisappear`, the instrument will show that the effect
  /// never completed.
  ///
  /// - Parameters:
  ///   - prefix: A string to print at the beginning of the formatted message for the signpost.
  ///   - log: An `OSLog` to use for signposts.
  /// - Returns: A reducer that has been enhanced with instrumentation.
  @inlinable
  public func signpost(
    _ prefix: String = "",
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
  ) -> EffectTask<Base.Action> {
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
