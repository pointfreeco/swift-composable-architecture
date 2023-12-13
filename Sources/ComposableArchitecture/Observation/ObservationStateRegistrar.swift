import Perception

/// Provides storage for tracking and access to data changes.
public struct ObservationStateRegistrar: Sendable {
  public var id = ObservableStateID()
  private let registrar = PerceptionRegistrar()
  public init() {}

  public mutating func _$willSet() { id._$willSet() }
  public mutating func _$didSet() { id._$didSet() }
}

extension ObservationStateRegistrar: Equatable, Hashable, Codable {
  public static func == (_: Self, _: Self) -> Bool { true }
  public func hash(into hasher: inout Hasher) {}
  public init(from decoder: Decoder) throws { self.init() }
  public func encode(to encoder: Encoder) throws {}
}

#if canImport(Observation)
  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  extension ObservationStateRegistrar {
    public func access<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.access(subject, keyPath: keyPath)
    }

    public func mutate<Subject: Observable, Member, Value>(
      _ subject: Subject,
      keyPath: KeyPath<Subject, Member>,
      _ value: inout Value,
      _ newValue: Value,
      _ isIdentityEqual: (Value, Value) -> Bool
    ) {
      if isIdentityEqual(value, newValue) {
        value = newValue
      } else {
        self.registrar.withMutation(of: subject, keyPath: keyPath) {
          value = newValue
        }
      }
    }

    public func willSet<Subject: Observable, Member>(
      _ subject: Subject,
      keyPath: KeyPath<Subject, Member>,
      _ member: inout Member
    ) -> Member {
      return member
    }

    public func willSet<Subject: Observable, Member: ObservableState>(
      _ subject: Subject,
      keyPath: KeyPath<Subject, Member>,
      _ member: inout Member
    ) -> Member {
      member._$willSet()
      return member
    }

    public func didSet<Subject: Observable, Member>(
      _ subject: Subject,
      keyPath: KeyPath<Subject, Member>,
      _ member: inout Member,
      _ oldValue: Member,
      _ isIdentityEqual: (Member, Member) -> Bool
    ) {
      if !isIdentityEqual(oldValue, member) {
        let newValue = member
        member = oldValue
        self.mutate(subject, keyPath: keyPath, &member, newValue, isIdentityEqual)
      }
    }

    public func didSet<Subject: Observable, Member: ObservableState>(
      _ subject: Subject,
      keyPath: KeyPath<Subject, Member>,
      _ member: inout Member,
      _ oldValue: Member,
      _ isIdentityEqual: (Member, Member) -> Bool
    ) {
      if isIdentityEqual(oldValue, member) {
        member._$didSet()
      } else {
        let newValue = member
        member = oldValue
        self.mutate(subject, keyPath: keyPath, &member, newValue, isIdentityEqual)
      }
    }
  }
#endif

extension ObservationStateRegistrar {
  @_disfavoredOverload
  public func access<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    self.registrar.access(subject, keyPath: keyPath)
  }

  @_disfavoredOverload
  public func mutate<Subject: Perceptible, Member, Value>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ value: inout Value,
    _ newValue: Value,
    _ isIdentityEqual: (Value, Value) -> Bool
  ) {
    if isIdentityEqual(value, newValue) {
      value = newValue
    } else {
      self.registrar.withMutation(of: subject, keyPath: keyPath) {
        value = newValue
      }
    }
  }

  @_disfavoredOverload
  public func willSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ member: inout Member
  ) -> Member {
    return member
  }

  @_disfavoredOverload
  public func willSet<Subject: Perceptible, Member: ObservableState>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ member: inout Member
  ) -> Member {
    member._$willSet()
    return member
  }

  @_disfavoredOverload
  public func didSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ member: inout Member,
    _ oldValue: Member,
    _ isIdentityEqual: (Member, Member) -> Bool
  ) {
    if !isIdentityEqual(oldValue, member) {
      let newValue = member
      member = oldValue
      self.mutate(subject, keyPath: keyPath, &member, newValue, isIdentityEqual)
    }
  }

  @_disfavoredOverload
  public func didSet<Subject: Perceptible, Member: ObservableState>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ member: inout Member,
    _ oldValue: Member,
    _ isIdentityEqual: (Member, Member) -> Bool
  ) {
    if isIdentityEqual(oldValue, member) {
      member._$didSet()
    } else {
      let newValue = member
      member = oldValue
      self.mutate(subject, keyPath: keyPath, &member, newValue, isIdentityEqual)
    }
  }
}
