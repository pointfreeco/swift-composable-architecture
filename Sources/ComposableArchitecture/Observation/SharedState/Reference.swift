import CustomDump

protocol Reference<Value>:
  AnyObject, CustomDumpRepresentable, CustomStringConvertible, _CustomDiffObject
{
  associatedtype Value

  var currentValue: Value { get set }
  var snapshot: Value? { get set }

  func takeSnapshot()
  func clearSnapshot()
}

extension Reference {
  func takeSnapshot() {
    self.snapshot = self.currentValue
  }

  func clearSnapshot() {
    self.snapshot = nil
  }

  func assertUnchanged() {
    if let snapshot = self.snapshot,
      let difference = diff(snapshot, self.currentValue, format: .proportional)
    {
      XCTFail(
        """
        Tracked changes to '\(self.description)' but failed to assert: …

        \(difference.indent(by: 2))

        (Before: −, After: +)

        Call 'Shared<\(Value.self)>.assert' to exhaustively test these changes, or call \
        'skipChanges' to ignore them.
        """
      )
    }
    self.clearSnapshot()
  }
}

extension Reference {
  var customDumpValue: Any {
    self.currentValue
  }

  var _customDiffValues: (Any, Any) {
    (self.snapshot ?? self.currentValue, self.currentValue)
  }
}
