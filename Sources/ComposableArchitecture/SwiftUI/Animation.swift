import SwiftUI

extension ViewStore {
  /// Sends an action to the store with a given animation.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - animation: An animation.
  public func send(_ action: Action, animation: Animation?) {
    withAnimation(animation) {
      self.send(action)
    }
  }
}
