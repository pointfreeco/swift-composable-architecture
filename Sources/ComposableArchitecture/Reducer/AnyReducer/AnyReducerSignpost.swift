import Combine
import os.signpost

extension AnyReducer {
  /// Instruments the reducer with
  /// [signposts](https://developer.apple.com/documentation/os/logging/recording_performance_data).
  /// Each invocation of the reducer will be measured by an interval, and the lifecycle of its
  /// effects will be measured with interval and event signposts.
  ///
  /// To use, build your app for Instruments (⌘I), create a blank instrument, and then use the "+"
  /// icon at top right to add the signpost instrument. Start recording your app (red button at top
  /// left) and then you should see timing information for every action sent to the store and every
  /// effect executed.
  ///
  /// Effect instrumentation can be particularly useful for inspecting the lifecycle of long-living
  /// effects. For example, if you start an effect (e.g. a location manager) in `onAppear` and
  /// forget to tear down the effect in `onDisappear`, it will clearly show in Instruments that the
  /// effect never completed.
  ///
  /// - Parameters:
  ///   - prefix: A string to print at the beginning of the formatted message for the signpost.
  ///   - log: An `OSLog` to use for signposts.
  /// - Returns: A reducer that has been enhanced with instrumentation.
  @available(
    iOS,
    deprecated: 9999,
    message:
      """
      This API has been soft-deprecated in favor of 'ReducerProtocol.signpost'. Read the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      """
      This API has been soft-deprecated in favor of 'ReducerProtocol.signpost'. Read the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      """
      This API has been soft-deprecated in favor of 'ReducerProtocol.signpost'. Read the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      """
      This API has been soft-deprecated in favor of 'ReducerProtocol.signpost'. Read the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  public func signpost(
    _ prefix: String = "",
    log: OSLog = OSLog(
      subsystem: "co.pointfree.composable-architecture",
      category: "Reducer Instrumentation"
    )
  ) -> Self {
    guard log.signpostsEnabled else { return self }

    // NB: Prevent rendering as "N/A" in Instruments
    let zeroWidthSpace = "\u{200B}"

    let prefix = prefix.isEmpty ? zeroWidthSpace : "[\(prefix)] "

    return Self { state, action, environment in
      var actionOutput: String!
      if log.signpostsEnabled {
        actionOutput = debugCaseOutput(action)
        os_signpost(.begin, log: log, name: "Action", "%s%s", prefix, actionOutput)
      }
      let effects = self.run(&state, action, environment)
      if log.signpostsEnabled {
        os_signpost(.end, log: log, name: "Action")
        return
          effects
          .effectSignpost(prefix, log: log, actionOutput: actionOutput)
      }
      return effects
    }
  }
}

extension EffectPublisher where Failure == Never {
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

  return (value as? CustomDebugStringConvertible)?.debugDescription
    ?? "\(abbreviated ? "" : typeName(type(of: value)))\(debugCaseOutputHelp(value))"
}

private func isUnlabeledArgument(_ label: String) -> Bool {
  label.firstIndex(where: { $0 != "." && !$0.isNumber }) == nil
}
