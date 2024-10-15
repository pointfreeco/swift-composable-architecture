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

@_transparent
func sendableKeyPath(
  _ keyPath: AnyKeyPath
) -> _SendableAnyKeyPath {
  #if compiler(>=6)
    unsafeBitCast(keyPath, to: _SendableAnyKeyPath.self)
  #else
    keyPath
  #endif
}
