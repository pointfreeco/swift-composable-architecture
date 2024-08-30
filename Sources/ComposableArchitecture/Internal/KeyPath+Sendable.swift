#if compiler(>=6)
  public typealias _AnyKeyPath = AnyKeyPath & Sendable
  public typealias _PartialKeyPath<Root> = PartialKeyPath<Root> & Sendable
  public typealias _KeyPath<Root, Value> = KeyPath<Root, Value> & Sendable
  public typealias _WritableKeyPath<Root, Value> = WritableKeyPath<Root, Value> & Sendable
  public typealias _ReferenceWritableKeyPath<Root, Value> = ReferenceWritableKeyPath<Root, Value>
    & Sendable
  public typealias _PartialCaseKeyPath<Root> = PartialCaseKeyPath<Root> & Sendable
  public typealias _CaseKeyPath<Root, Value> = CaseKeyPath<Root, Value> & Sendable
#else
  public typealias _AnyKeyPath = AnyKeyPath
  public typealias _PartialKeyPath<Root> = PartialKeyPath<Root>
  public typealias _KeyPath<Root, Value> = KeyPath<Root, Value>
  public typealias _WritableKeyPath<Root, Value> = WritableKeyPath<Root, Value>
  public typealias _ReferenceWritableKeyPath<Root, Value> = ReferenceWritableKeyPath<Root, Value>
  public typealias _PartialCaseKeyPath<Root> = PartialCaseKeyPath<Root>
  public typealias _CaseKeyPath<Root, Value> = CaseKeyPath<Root, Value>
#endif
