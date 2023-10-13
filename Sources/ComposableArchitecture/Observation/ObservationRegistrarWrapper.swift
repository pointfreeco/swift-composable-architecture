#if canImport(Observation)
  import Observation
#endif

// NB: A wrapper around `Observation.ObservationRegistrar` for availability.
public struct ObservationRegistrarWrapper: Sendable {
  private let _rawValue: AnySendable

  public init() {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      self._rawValue = AnySendable(ObservationRegistrar())
    } else {
      self._rawValue = AnySendable(TCAObservationRegistrar())
    }
  }
}

extension ObservationRegistrarWrapper: Equatable, Hashable, Codable {
  public static func == (_: Self, _: Self) -> Bool { true }
  public func hash(into hasher: inout Hasher) {}
  public init(from decoder: Decoder) throws { self.init() }
  public func encode(to encoder: Encoder) throws {}
}

extension ObservationRegistrarWrapper {
//  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
//  init(rawValue: ObservationRegistrar) {
//    self._rawValue = AnySendable(rawValue)
//  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  var rawValue: ObservationRegistrar {
    self._rawValue.base as! ObservationRegistrar
  }

//  init(rawValue: TCAObservationRegistrar) {
//    self._rawValue = AnySendable(rawValue)
//  }

  var tcaRawValue: TCAObservationRegistrar {
    self._rawValue.base as! TCAObservationRegistrar
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  public func access<Subject: Observable, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    self.rawValue.access(subject, keyPath: keyPath)
  }
  public func access<Subject: TCAObservable, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    self.tcaRawValue.access(subject, keyPath: keyPath)
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  public func willSet<Subject: Observable, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    self.rawValue.willSet(subject, keyPath: keyPath)
  }
  public func willSet<Subject: TCAObservable, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    self.tcaRawValue.willSet(subject, keyPath: keyPath)
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  public func didSet<Subject: Observable, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    self.rawValue.didSet(subject, keyPath: keyPath)
  }
  public func didSet<Subject: TCAObservable, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    self.tcaRawValue.didSet(subject, keyPath: keyPath)
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  public func withMutation<Subject: Observable, Member, T>(
    of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
  ) rethrows -> T {
    try self.rawValue.withMutation(of: subject, keyPath: keyPath, mutation)
  }
  public func withMutation<Subject: TCAObservable, Member, T>(
    of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
  ) rethrows -> T {
    try self.tcaRawValue.withMutation(of: subject, keyPath: keyPath, mutation)
  }
}
