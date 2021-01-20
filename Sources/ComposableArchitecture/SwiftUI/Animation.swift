import SwiftUI

extension ViewStore {
  public func send(_ action: Action, animation: Animation?) {
    withAnimation(animation) {
      self._send(action)
    }
  }
}
