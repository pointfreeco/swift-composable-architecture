import SwiftUI

@available(iOS, deprecated: 17, message: "TODO")
public enum PerceptionLocals {
  @TaskLocal public static var isInPerceptionTracking = false
}

@available(iOS, deprecated: 17, message: "TODO")
@MainActor
public struct WithPerceptionTracking<Content: View>: View {
  @State var id = 0
  let content: () -> Content
  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
  public var body: Content {
    if #available(iOS 17, *) {
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
