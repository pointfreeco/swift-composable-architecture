import OSLog

extension Reducer {
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
  @warn_unqualified_access
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

public struct _SignpostReducer<Base: Reducer>: Reducer {
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
  ) -> Effect<Base.Action> {
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
    }
    return effects
  }
}

extension Effect {
  @usableFromInline
  func effectSignpost(
    _ prefix: String,
    log: OSLog,
    actionOutput: String
  ) -> Self {
    let sid = OSSignpostID(log: log)

    switch self.operation {
    case .none:
      return self
    case let .publisher(publisher):
      return .init(
        operation: .publisher(
          publisher.handleEvents(
            receiveSubscription: { _ in
              os_signpost(
                .begin, log: log, name: "Effect", signpostID: sid, "%sStarted from %s", prefix,
                actionOutput)
            },
            receiveOutput: { value in
              os_signpost(
                .event, log: log, name: "Effect Output", "%sOutput from %s", prefix, actionOutput)
            },
            receiveCompletion: { completion in
              switch completion {
              case .finished:
                os_signpost(.end, log: log, name: "Effect", signpostID: sid, "%sFinished", prefix)
              }
            },
            receiveCancel: {
              os_signpost(.end, log: log, name: "Effect", signpostID: sid, "%sCancelled", prefix)
            }
          )
          .eraseToAnyPublisher()
        )
      )
    case let .run(priority, operation):
      return .init(
        operation: .run(priority) { send in
          os_signpost(
            .begin, log: log, name: "Effect", signpostID: sid, "%sStarted from %s", prefix,
            actionOutput
          )
          await operation(
            Send { action in
              os_signpost(
                .event, log: log, name: "Effect Output", "%sOutput from %s", prefix, actionOutput
              )
              send(action)
            }
          )
          if Task.isCancelled {
            os_signpost(.end, log: log, name: "Effect", signpostID: sid, "%sCancelled", prefix)
          }
          os_signpost(.end, log: log, name: "Effect", signpostID: sid, "%sFinished", prefix)
        }
      )
    }
  }
}

@usableFromInline
func debugCaseOutput(
  _ value: Any,
  abbreviated: Bool = false
) -> String {
  func debugCaseOutputHelp(_ value: Any) -> String {
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .enum:
      guard let child = mirror.children.first else {
        let childOutput = "\(value)"
        return childOutput == "\(typeName(type(of: value)))" ? "" : ".\(childOutput)"
      }
      let childOutput = debugCaseOutputHelp(child.value)
      return ".\(child.label ?? "")\(childOutput.isEmpty ? "" : "(\(childOutput))")"
    case .tuple:
      return mirror.children.map { label, value in
        let childOutput = debugCaseOutputHelp(value)
        return
          "\(label.map { isUnlabeledArgument($0) ? "_:" : "\($0):" } ?? "")\(childOutput.isEmpty ? "" : " \(childOutput)")"
      }
      .joined(separator: ", ")
    default:
      return ""
    }
  }

  return (value as? any CustomDebugStringConvertible)?.debugDescription
    ?? "\(abbreviated ? "" : typeName(type(of: value)))\(debugCaseOutputHelp(value))"
}

private func isUnlabeledArgument(_ label: String) -> Bool {
  label.firstIndex(where: { $0 != "." && !$0.isNumber }) == nil
}
