import SwiftUI

@available(iOS, deprecated: 17, message: "TODO")
public enum PerceptiveViewLocals {
  @TaskLocal public static var isInPerceptiveViewBody = false
}

@available(iOS, deprecated: 17, message: "TODO")
@MainActor
public struct PerceptiveView<Content: View>: View {
  @State var id = 0
  let content: () -> Content
  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
  public var body: some View {
    let _ = self.id
    withPerceptionTracking {
      PerceptiveViewLocals.$isInPerceptiveViewBody.withValue(true) {
        self.content()
      }
    } onChange: {
      Task { @MainActor in
        self.id += 1
      }
    }
  }
}
