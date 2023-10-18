#if canImport(Observation)
  import Observation
#endif

// NB: A wrapper around `Observation.ObservationRegistrar` for availability.
public struct ObservationRegistrarWrapper: Sendable {
  private let _rawValue: AnySendable

  public init() {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      #if swift(>=5.9)
        self._rawValue = AnySendable(ObservationRegistrar())
      #else
        self._rawValue = AnySendable(TCAObservationRegistrar())
      #endif
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

#if canImport(Observation)
  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  extension ObservationRegistrarWrapper {
    private var registrar: ObservationRegistrar {
      self._rawValue.base as! ObservationRegistrar
    }

    public func access<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.access(subject, keyPath: keyPath)
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

    public func withMutation<Subject: Observable, Member, T>(
      of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
    ) rethrows -> T {
      try self.registrar.withMutation(of: subject, keyPath: keyPath, mutation)
    }
  }
#endif

extension ObservationRegistrarWrapper {
  // TODO: Rename to something else
  private var tcaRegistrar: TCAObservationRegistrar {
    self._rawValue.base as! TCAObservationRegistrar
  }

  @_disfavoredOverload
  public func access<Subject: _TCAObservable, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    #if swift(>=5.9)
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
        func `open`<T: Observable>(_ subject: T) {
          self.registrar.access(
            subject,
            keyPath: unsafeDowncast(keyPath, to: KeyPath<T, Member>.self)
          )
        }
        if let subject = subject as? any Observable {
          open(subject)
        }
      } else {
        self.tcaRegistrar.access(subject, keyPath: keyPath)
      }
    #endif
  }

  @_disfavoredOverload
  public func withMutation<Subject: _TCAObservable, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    #if swift(>=5.9)
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
        let subject = subject as? any Observable
      {
        func `open`<S: Observable>(_ subject: S) throws -> T {
          return try self.registrar.withMutation(
            of: subject,
            keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self),
            mutation
          )
        }
        return try open(subject)
      } else {
        return try self.tcaRegistrar.withMutation(of: subject, keyPath: keyPath, mutation)
      }
    #else
      return try mutation()
    #endif
  }
}
