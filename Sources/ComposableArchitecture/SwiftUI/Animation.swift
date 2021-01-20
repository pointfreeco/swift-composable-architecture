import SwiftUI

extension ViewStore {
  // TODO: is withAnimation(nil) the same thing as doing nothing?
  public func send(_ action: Action, animation: Animation? = nil) {
    if let animation = animation {
      withAnimation(animation) {
        self.send(action)
      }
    } else {
      self.send(action)
    }
  }
}
