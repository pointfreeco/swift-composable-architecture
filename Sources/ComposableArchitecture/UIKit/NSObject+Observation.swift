#if canImport(Perception)
  import Foundation

  extension NSObject {
    public func observe(_ apply: @escaping () -> Void) {
      @Sendable func onChange() {
        withPerceptionTracking(apply) {
          Task { @MainActor in
            onChange()
          }
        }
      }
      onChange()
    }
  }
#endif
