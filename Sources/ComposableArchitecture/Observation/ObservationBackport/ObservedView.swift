import SwiftUI

enum ObservedViewLocal {
  @TaskLocal static var isExecutingBody = false
}

@MainActor
@available(iOS, deprecated: 17)
@available(macOS, deprecated: 14)
@available(tvOS, deprecated: 17)
@available(watchOS, deprecated: 10)
public struct ObservedView<Content: View>: View {
  @State var id = 0
  private let content: () -> Content
  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
  public var body: Content {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      return self.content()
    } else {
      let _ = self.id
      #if DEBUG
        return ObservedViewLocal.$isExecutingBody.withValue(true) {
          self.self.trackedContent()
        }
      #else
        return self.trackedContent()
      #endif
    }
  }

  func trackedContent() -> Content {
    TCAWithObservationTracking {
      self.content()
    } onChange: {
      Task { @MainActor in
        self.id += 1
      }
    }
  }
}
