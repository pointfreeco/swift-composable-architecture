import SwiftUI

@MainActor
public struct ObservedView<Content: View>: View {
  @State var id = 0
  let content: () -> Content
  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
  public var body: some View {
    let _ = self.id
    TCAWithObservationTracking {
      self.content()
    } onChange: {
      Task { @MainActor in
        self.id += 1
      }
    }
  }
}
