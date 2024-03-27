import CustomDump

#if canImport(Combine)
  import Combine
#endif

protocol Reference<Value>: AnyObject, CustomStringConvertible {
  associatedtype Value
  var currentValue: Value { get set }
  var snapshot: Value? { get set }
  #if canImport(Combine)
    var publisher: AnyPublisher<Value, Never> { get }
  #endif
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
