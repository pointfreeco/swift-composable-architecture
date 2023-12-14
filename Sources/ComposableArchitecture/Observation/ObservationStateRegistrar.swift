import Perception

/// Provides storage for tracking and access to data changes.
public struct ObservationStateRegistrar: Sendable {
  public private(set) var id = ObservableStateID()
  @usableFromInline
  let registrar = PerceptionRegistrar()
  public init() {}
  public mutating func _$willSet() { id._$willSet() }
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
  /// Registers access to a specific property for observation.
  ///
  /// - Parameters:
  ///   - subject: An instance of an observable type.
  ///   - keyPath: The key path of an observed property.
    public func access<Subject: Observable, Member>(
      _ subject: Subject, 
      keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.access(subject, keyPath: keyPath)
    }

    /// Mutates a value to a new value, and decided to notify observers based on the identity of
    /// the value.
    ///
    /// - Parameters:
    ///   - subject: An instance of an observable type.
    ///   - keyPath: The key path of an observed property.
    ///   - value: The value being mutated.
    ///   - newValue: The new value to mutate with.
    ///   - isIdentityEqual: A comparison function that determines whether two values have the same
    ///                      identity or not.
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
  
    /// A no-op for non-observable values.
    ///
    /// See ``willSet(_:keyPath:_:)-3ybfo`` for info on what this method does when used with
    /// observable values.
    public func willSet<Subject: Observable, Member>(
      _ subject: Subject,
      keyPath: KeyPath<Subject, Member>,
      _ member: inout Member
    ) -> Member {
      member
    }
  
    /// A property observation called before setting the value of the subject.
    ///
    /// - Parameters:
    ///   - subject: An instance of an observable type.`
    ///   - keyPath: The key path of an observed property.
    ///   - member: The value in the subject that will be set.
    public func willSet<Subject: Observable, Member: ObservableState>(
      _ subject: Subject,
      keyPath: KeyPath<Subject, Member>,
      _ member: inout Member
    ) -> Member {
      member._$willSet()
      return member
    }
  
  /// A property observation called after setting the value of the subject.
  ///
  /// If the identity of the value changed between ``willSet(_:keyPath:_:)-3ybfo`` and
  /// ``didSet(_:keyPath:_:_:_:)-q3nd``, 
  /// - Parameters:
  ///   - subject: <#subject description#>
  ///   - keyPath: <#keyPath description#>
  ///   - member: <#member description#>
  ///   - oldValue: <#oldValue description#>
  ///   - isIdentityEqual: <#isIdentityEqual description#>
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
  }
#endif

extension ObservationStateRegistrar {
  @_disfavoredOverload
  @inlinable
  public func access<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    self.registrar.access(subject, keyPath: keyPath)
  }

  /// See ``mutate(_:keyPath:_:_:_:)-2w75m``
  @_disfavoredOverload
  @inlinable
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

  // TODO: willModify, didModify, _$willModify

  @_disfavoredOverload
  @inlinable
  public func willSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ member: inout Member
  ) -> Member {
    return member
  }

  @_disfavoredOverload
  @inlinable
  public func willSet<Subject: Perceptible, Member: ObservableState>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ member: inout Member
  ) -> Member {
    member._$willSet()
    return member
  }

  @_disfavoredOverload
  @inlinable
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
}
