#if canImport(Observation)
  import Observation
#endif

// NB: A wrapper around `Observation.ObservationRegistrar` for availability.
public struct ObservationRegistrarWrapper: Sendable {
  private let _rawValue: AnySendable

  public init() {
    #if canImport(Observation)
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
        self._rawValue = AnySendable(ObservationRegistrar())
      } else {
        self._rawValue = AnySendable(())
      }
    #else
      self._rawValue = AnySendable(())
    #endif
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
    var rawValue: ObservationRegistrar {
      self._rawValue.base as! ObservationRegistrar
    }

    public func access<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.rawValue.access(subject, keyPath: keyPath)
    }

    public func willSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.rawValue.willSet(subject, keyPath: keyPath)
    }

    public func didSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.rawValue.didSet(subject, keyPath: keyPath)
    }

    public func withMutation<Subject: Observable, Member, T>(
      of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
    ) rethrows -> T {
      try self.rawValue.withMutation(of: subject, keyPath: keyPath, mutation)
    }
  }
#endif
