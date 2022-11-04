import Foundation

@usableFromInline
var isRunningForPreviews: Bool {
  #if DEBUG
  return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  #else
  return false
  #endif
}
