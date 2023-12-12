import Perception

/// Provides storage for tracking and access to data changes.
public struct ObservationStateRegistrar: Sendable {
  public var id = ObservableStateID()
  private let registrar = PerceptionRegistrar()
  public init() {}
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

    public func withMutation<Subject: Observable, Member, T>(
      of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
    ) rethrows -> T {
      try self.registrar.withMutation(of: subject, keyPath: keyPath, mutation)
    }
    
    public func willSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.willSet(subject, keyPath: keyPath)
    }

    public func didSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.didSet(subject, keyPath: keyPath)
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
  public func withMutation<Subject: Perceptible, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    try self.registrar.withMutation(of: subject, keyPath: keyPath, mutation)
  }

  @_disfavoredOverload
  public func willSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    self.registrar.willSet(subject, keyPath: keyPath)
  }

  @_disfavoredOverload
  public func didSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    self.registrar.didSet(subject, keyPath: keyPath)
  }
}
