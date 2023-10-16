import SwiftUI

enum ObservedViewLocal {
  @TaskLocal static var isExecutingBody = false
}

// TODO: try function instead of view?
//public func _ObservedView() -> Content {
//}

@available(iOS, deprecated: 17)
@MainActor
public struct ObservedView<Content: View>: View {
  @State var id = 0
  let content: () -> Content
  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
  public var body: Content {
    if #available(iOS 17, *) {
      return self.content()
    } else {
      // TODO: only do in DEBUG
      return ObservedViewLocal.$isExecutingBody.withValue(true) {
        let _ = self.id
        return TCAWithObservationTracking {
          self.content()
        } onChange: {
          Task { @MainActor in
            self.id += 1
          }
        }
      }
    }
  }
}
