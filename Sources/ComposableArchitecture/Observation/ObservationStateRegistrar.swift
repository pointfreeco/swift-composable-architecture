@available(iOS, introduced: 17)
@available(macOS, introduced: 14)
@available(tvOS, introduced: 17)
@available(watchOS, introduced: 10)
public struct ObservationStateRegistrar: Codable, Equatable, Hashable, Sendable {
  public let id = StateID()
  public let _$observationRegistrar = ObservationRegistrar()
  public init() {}

  public func access<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>)
  where Subject: Observable {
    self._$observationRegistrar.access(subject, keyPath: keyPath)
  }

  public func willSet<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>)
  where Subject: Observable {
    self._$observationRegistrar.willSet(subject, keyPath: keyPath)
  }

  public func didSet<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>)
  where Subject: Observable {
    self._$observationRegistrar.didSet(subject, keyPath: keyPath)
  }

  public func withMutation<Subject, Member, T>(
    of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
  ) rethrows -> T where Subject: Observable {
    try self._$observationRegistrar.withMutation(of: subject, keyPath: keyPath, mutation)
  }

  public init(from decoder: Decoder) throws {
    self.init()
  }
  public func encode(to encoder: Encoder) throws {}
}
