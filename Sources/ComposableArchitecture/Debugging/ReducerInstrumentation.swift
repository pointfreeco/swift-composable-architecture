import Combine
import os.signpost

extension Reducer {
  /// Instruments the reducer with signpost. Each invocation of the reducer will be measured by
  /// an interval, and the lifecycle of its effects will be measured with interval and event
  /// signposts.
  ///
  /// - Parameters:
  ///   - prefix: A string to print at the beginning of the formatted message for the signpost.
  ///   - log: An optional `OSLog` to use for signposts.
  /// - Returns: A reducer that has been enhanced with instrumentation.
  public func signpost(
    _ prefix: String = "",
    log: OSLog = OSLog(subsystem: "co.pointfree.composable-architecture", category: "Reducer Instrumentation")
  ) -> Self {
    let prefix = prefix.isEmpty ? "" : "\(prefix): "

    return Self { state, action, environment in
      if log.signpostsEnabled {
        os_signpost(.begin, log: log, name: "Action", "%s%s", prefix, debugCaseOutput(action))
      }
      let effects = self.callAsFunction(&state, action, environment)
      if log.signpostsEnabled {
        os_signpost(.end, log: log, name: "Action")
      }
      return effects
        .effectSignpost(log: log, action: action)
        .eraseToEffect()
    }
  }
}

extension Publisher {
  func effectSignpost(
    log: OSLog,
    action: Output
  ) -> Publishers.HandleEvents<Self> {
    guard log.signpostsEnabled else { return self.handleEvents() }
    let actionOutput = debugCaseOutput(action)
    let sid = OSSignpostID(log: log)

    return self
      .handleEvents(
        receiveSubscription: { _ in
          guard log.signpostsEnabled else { return }
          os_signpost(.begin, log: log, name: "Effect Started", signpostID: sid, "From %s", actionOutput)
      },
        receiveOutput: { value in
          guard log.signpostsEnabled else { return }
          os_signpost(.event, log: log, name: "Effect Output", "Output from %s", actionOutput)
      },
        receiveCompletion: { completion in
          guard log.signpostsEnabled else { return }
          switch completion {
          case .failure:
            os_signpost(.end, log: log, name: "Effect Started", signpostID: sid, "Failed")
          case .finished:
            os_signpost(.end, log: log, name: "Effect Started", signpostID: sid, "Finished")
          }
      },
        receiveCancel: {
          guard log.signpostsEnabled else { return }
          os_signpost(.end, log: log, name: "Effect Started", signpostID: sid, "Cancelled")
      })
  }
}

func debugCaseOutput(_ value: Any) -> String {
  let mirror = Mirror(reflecting: value)
  switch mirror.displayStyle {
  case .enum:
    guard let child = mirror.children.first else {
      let childOutput = "\(value)"
      return childOutput == "\(type(of: value))" ? "" : ".\(childOutput)"
    }
    let childOutput = debugCaseOutput(child.value)
    return ".\(child.label ?? "")\(childOutput.isEmpty ? "" : "(\(childOutput))")"
  case .tuple:
    return mirror.children.map { label, value in
      let childOutput = debugCaseOutput(value)
      return "\(label.map { "\($0):" } ?? "")\(childOutput.isEmpty ? "" : " \(childOutput)")"
    }
    .joined(separator: ", ")
  default:
    return ""
  }
}
