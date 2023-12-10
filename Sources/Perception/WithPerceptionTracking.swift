import SwiftUI

@available(iOS, deprecated: 17, message: "TODO")
@available(macOS, deprecated: 14, message: "TODO")
@available(tvOS, deprecated: 17, message: "TODO")
@available(watchOS, deprecated: 10, message: "TODO")
public enum PerceptionLocals {
  @TaskLocal public static var isInPerceptionTracking = false
  @TaskLocal public static var isInWithoutPerceptionChecking = false
}

@available(iOS, deprecated: 17, message: "TODO")
@available(macOS, deprecated: 14, message: "TODO")
@available(tvOS, deprecated: 17, message: "TODO")
@available(watchOS, deprecated: 10, message: "TODO")
@MainActor
public struct WithPerceptionTracking<Content: View>: View {
  @State var id = 0
  let content: () -> Content
  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
  public var body: Content {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      return self.content()
    } else {
      let _ = self.id
      return withPerceptionTracking {
        PerceptionLocals.$isInPerceptionTracking.withValue(true) {
          self.content()
        }
      } onChange: {
        Task { @MainActor in
          self.id += 1
        }
      }
    }
  }
}
