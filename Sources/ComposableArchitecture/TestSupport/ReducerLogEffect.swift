import Combine
import os.signpost

var loggedEffect = Log()

struct Log {
  var log : [String] = []
  var ongoingActions = Set<String>()

  var logContent : String {
    if !log.isEmpty {
      return """

          Log:

          \(log.joined(separator: "\n"))
      """
    }
    return ""
  }
  
  var ongoingActionsContent : String {
    if !ongoingActions.isEmpty {
      return """

          Not Finished Actions(\(ongoingActions.count)):

          - \(ongoingActions.joined(separator: "\n- "))
      """
    }
    return ""
  }
}

extension Reducer {
  public func logEffect(
    _ prefix: String = ""
  ) -> Self {
    // NB: Prevent rendering as "N/A" in Instruments
    let zeroWidthSpace = "\u{200B}"
    
    let prefix = prefix.isEmpty ? zeroWidthSpace : "[\(prefix)] "
    
    return Self { state, action, environment in
      let actionOutput = debugCaseOutput(action)
      let content = "\tBegin: Action \(prefix)\(actionOutput)"
      loggedEffect.log.append(content)
      loggedEffect.ongoingActions.insert(actionOutput)
      
      return
        self.run(&state, action, environment)
        .logger(prefix, actionOutput: actionOutput)
        .eraseToEffect()
    }
  }
}

extension Publisher where Failure == Never {
  func logger(
    _ prefix: String,
    actionOutput: String
  ) -> Publishers.HandleEvents<Self> {
    let endAction = {
      loggedEffect.log.append("\tEnd: Action \(prefix)\(actionOutput)")
      loggedEffect.ongoingActions.remove(actionOutput)
    }
    return
      self
      .handleEvents(
        receiveSubscription: { _ in
          loggedEffect.log.append("\t\tBegin: Effect Started")
        },
        receiveOutput: { value in
          loggedEffect.log.append("\t\tEvent: Effect Receive Output")
        },
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            loggedEffect.log.append("\t\tEnd: Effect Finished")
            endAction()
          }
        },
        receiveCancel: {
          loggedEffect.log.append("\t\tEnd: Effect Cancelled")
          endAction()
        })
  }
}
