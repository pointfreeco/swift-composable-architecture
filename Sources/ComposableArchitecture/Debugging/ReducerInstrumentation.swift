import os.signpost

extension Reducer {
  public func signpost(
    logger: OSLog = OSLog(subsystem: "co.composable-architecture", category: "Reducer Instrumentation"),
    eventLogger: OSLog = OSLog(subsystem: "co.composable-architecture", category: .pointsOfInterest)
  ) -> Self {
    return Self { state, action, environment in
      if logger.signpostsEnabled {
        os_signpost(.begin, log: logger, name: "Action", "%s", debugCaseOutput(action))
      }
      let effects = self.callAsFunction(&state, action, environment)
      if logger.signpostsEnabled {
        os_signpost(.end, log: logger, name: "Action")
      }
      return effects
        .signpost(action: action, logger: logger, eventLogger: eventLogger)
    }
  }
}

extension Effect {
  public func signpost(
    action: Output,
    logger: OSLog = OSLog(subsystem: "co.composable-architecture", category: "Reducer Instrumentation"),
    eventLogger: OSLog = OSLog(subsystem: "co.composable-architecture", category: .pointsOfInterest)
  ) -> Effect {
    let sid = OSSignpostID(log: logger)

    return self.handleEvents(
      receiveSubscription: { _ in
        guard logger.signpostsEnabled else { return }
        os_signpost(.begin, log: logger, name: "Effect", signpostID: sid, "Started by: %s", debugCaseOutput(action))
    },
      receiveOutput: { value in
        guard logger.signpostsEnabled else { return }
        os_signpost(.event, log: eventLogger, name: "Effect Output", "Output from: %s", debugCaseOutput(action))
    },
      receiveCompletion: { completion in
        guard logger.signpostsEnabled else { return }
        switch completion {
        case .failure:
          os_signpost(.end, log: logger, name: "Effect", signpostID: sid, "Failed: %s", debugCaseOutput(action))
        case .finished:
          os_signpost(.end, log: logger, name: "Effect", signpostID: sid, "Finished: %s", debugCaseOutput(action))
        }
    },
      receiveCancel: {
        guard logger.signpostsEnabled else { return }
        os_signpost(.end, log: logger, name: "Effect", signpostID: sid, "Cancelled: %s", debugCaseOutput(action))
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
