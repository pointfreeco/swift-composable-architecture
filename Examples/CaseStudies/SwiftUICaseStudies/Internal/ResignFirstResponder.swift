import SwiftUI

extension Binding {
  /// SwiftUI will print errors to the console about "AttributeGraph: cycle detected" if you disable
  /// a text field while it is focused. This hack will force all fields to unfocus before we write
  /// to a binding that may disable the fields.
  ///
  /// See also: https://stackoverflow.com/a/69653555
  @MainActor
  func resignFirstResponder() -> Self {
    Self(
      get: { self.wrappedValue },
      set: { newValue, transaction in
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        self.transaction(transaction).wrappedValue = newValue
      }
    )
  }
}
