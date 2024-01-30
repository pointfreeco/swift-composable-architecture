import SwiftUI

extension Binding {
  func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
    self._isPresent
  }
}

extension Optional {
  fileprivate var _isPresent: Bool {
    get { self != nil }
    set {
      guard !newValue else { return }
      self = nil
    }
  }
}
