// https://github.com/apple/swift-evolution/blob/c9ab716f7914697a34f5a6263b1d14ce43b95e70/proposals/0302-concurrent-value-and-concurrent-closures.md#adaptor-types-for-legacy-codebases
@propertyWrapper
struct UncheckedSendable<Wrapped> : @unchecked Sendable {
  var wrappedValue: Wrapped
  init(wrappedValue: Wrapped) {
    self.wrappedValue = wrappedValue
  }
}
