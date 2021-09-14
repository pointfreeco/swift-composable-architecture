import SwiftUI

extension Binding {
  func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
    .init(
      get: { self.wrappedValue != nil },
      set: { isPresent in
        if !isPresent {
          withTransaction(self.transaction) {
            self.wrappedValue = nil
          }
        }
      }
    )
  }
}
