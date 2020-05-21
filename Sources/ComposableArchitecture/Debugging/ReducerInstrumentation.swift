import os.signpost

extension Reducer {
  public func signpost(
    _ prefix: String = "",
    logger: OSLog = OSLog(subsystem: "co.composable-architecture", category: "Reducer Instrumentation")
  ) -> Self {
    let prefix = prefix.isEmpty ? "" : "\(prefix): "

    return Self { state, action, environment in
      if logger.signpostsEnabled {
        os_signpost(.begin, log: logger, name: "Action", "%s%s", prefix, debugCaseOutput(action))
      }
      let effects = self.callAsFunction(&state, action, environment)
      if logger.signpostsEnabled {
        os_signpost(.end, log: logger, name: "Action")
      }
      return effects
        .signpost(prefix, action: action, logger: logger)
    }
  }
}

extension Effect {
  public func signpost(
    _ prefix: String,
    action: Output,
    logger: OSLog = OSLog(subsystem: "co.composable-architecture", category: "Reducer Instrumentation")
  ) -> Effect {
    guard logger.signpostsEnabled else { return self }

    let sid = OSSignpostID(log: logger)
    let caseOutput = debugCaseOutput(action)

    return self.handleEvents(
      receiveSubscription: { _ in
        os_signpost(.begin, log: logger, name: "Effect", signpostID: sid, "%sStarted from %s", prefix, caseOutput)
    },
      receiveOutput: { value in
        os_signpost(.event, log: logger, name: "Effect Output", "%s Output from %s", prefix, caseOutput)
    },
      receiveCompletion: { completion in
        switch completion {
        case .failure:
          os_signpost(.end, log: logger, name: "Effect", signpostID: sid, "Failed")
        case .finished:
          os_signpost(.end, log: logger, name: "Effect", signpostID: sid, "Finished")
        }
    },
      receiveCancel: {
        os_signpost(.end, log: logger, name: "Effect", signpostID: sid, "Cancelled")
    })
    .eraseToEffect()
  }
}

private func debugCaseOutput(_ value: Any) -> String {
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
