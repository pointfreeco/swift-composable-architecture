#if compiler(>=6)
  public typealias _SendableAnyKeyPath = any AnyKeyPath & Sendable
  public typealias _SendablePartialKeyPath<Root> = any PartialKeyPath<Root> & Sendable
  public typealias _SendableKeyPath<Root, Value> = any KeyPath<Root, Value> & Sendable
  public typealias _SendableWritableKeyPath<Root, Value> = any WritableKeyPath<Root, Value>
    & Sendable
  public typealias _SendableReferenceWritableKeyPath<Root, Value> = any ReferenceWritableKeyPath<
    Root, Value
  >
    & Sendable
  public typealias _SendablePartialCaseKeyPath<Root> = any PartialCaseKeyPath<Root> & Sendable
  public typealias _SendableCaseKeyPath<Root, Value> = any CaseKeyPath<Root, Value> & Sendable
#else
  public typealias _SendableAnyKeyPath = AnyKeyPath
  public typealias _SendablePartialKeyPath<Root> = PartialKeyPath<Root>
  public typealias _SendableKeyPath<Root, Value> = KeyPath<Root, Value>
  public typealias _SendableWritableKeyPath<Root, Value> = WritableKeyPath<Root, Value>
  public typealias _SendableReferenceWritableKeyPath<Root, Value> = ReferenceWritableKeyPath<
    Root, Value
  >
  public typealias _SendablePartialCaseKeyPath<Root> = PartialCaseKeyPath<Root>
  public typealias _SendableCaseKeyPath<Root, Value> = CaseKeyPath<Root, Value>
#endif

// NB: Dynamic member lookup does not currently support sendable key paths and even breaks
//     autocomplete.
//
//     * https://github.com/swiftlang/swift/issues/77035
//     * https://github.com/swiftlang/swift/issues/77105
extension _AppendKeyPath {
  @_transparent
  func unsafeSendable() -> _SendableAnyKeyPath
  where Self == AnyKeyPath {
    #if compiler(>=6)
      unsafeBitCast(self, to: _SendableAnyKeyPath.self)
    #else
      self
    #endif
  }

  @_transparent
  func unsafeSendable<Root>() -> _SendablePartialKeyPath<Root>
  where Self == PartialKeyPath<Root> {
    #if compiler(>=6)
      unsafeBitCast(self, to: _SendablePartialKeyPath<Root>.self)
    #else
      self
    #endif
  }

  @_transparent
  func unsafeSendable<Root, Value>() -> _SendableKeyPath<Root, Value>
  where Self == KeyPath<Root, Value> {
    #if compiler(>=6)
      unsafeBitCast(self, to: _SendableKeyPath<Root, Value>.self)
    #else
      self
    #endif
  }

  @_transparent
  func unsafeSendable<Root, Value>() -> _SendableWritableKeyPath<Root, Value>
  where Self == WritableKeyPath<Root, Value> {
    #if compiler(>=6)
      unsafeBitCast(self, to: _SendableWritableKeyPath<Root, Value>.self)
    #else
      self
    #endif
  }

  @_transparent
  func unsafeSendable<Root, Value>() -> _SendableReferenceWritableKeyPath<Root, Value>
  where Self == ReferenceWritableKeyPath<Root, Value> {
    #if compiler(>=6)
      unsafeBitCast(self, to: _SendableReferenceWritableKeyPath<Root, Value>.self)
    #else
      self
    #endif
  }

  @_transparent
  func unsafeSendable<Root, Value>() -> _SendableCaseKeyPath<Root, Value>
  where Self == CaseKeyPath<Root, Value> {
    #if compiler(>=6)
      unsafeBitCast(self, to: _SendableCaseKeyPath<Root, Value>.self)
    #else
      self
    #endif
  }
}
