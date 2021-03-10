#if DEBUG
  import Foundation

  extension Effect {
    static func failing(_ message: String = "") -> Self {
      .fireAndForget {
        _XCTFail(message.isEmpty ? "A failing effect was subscribed to" : message)
      }
    }
  }

  // NB: Dynamically load XCTest to prevent leaking its symbols into our library code.
  private func _XCTFail(_ message: String = "") {
    guard
      let XCTestObservationCenter = NSClassFromString("XCTestObservationCenter")
        as Any as? NSObjectProtocol,
      let shared = XCTestObservationCenter.perform(Selector(("sharedTestObservationCenter")))?
        .takeUnretainedValue(),
      let observers = shared.perform(Selector(("observers")))?
        .takeUnretainedValue() as? [AnyObject],
      let observer = observers
        .first(where: { NSStringFromClass(type(of: $0)) == "XCTestMisuseObserver" }),
      let currentTestCase = observer.perform(Selector(("currentTestCase")))?
        .takeUnretainedValue(),
      let XCTIssue = NSClassFromString("XCTIssue")
        as Any as? NSObjectProtocol,
      let alloc = XCTIssue.perform(NSSelectorFromString("alloc"))?
        .takeUnretainedValue(),
      let issue = alloc
        .perform(
          Selector(("initWithType:compactDescription:")),
          with: 0,
          with: "failed\(message.isEmpty ? "" : " - \(message)")"
        )?
        .takeUnretainedValue()
    else { return }

    _ = currentTestCase.perform(Selector(("recordIssue:")), with: issue)
  }
#endif
