#if canImport(Observation)
  import Observation
#endif

// NB: A wrapper around `Observation.ObservationRegistrar` for availability.
struct ObservationRegistrarWrapper: Sendable {
  private let _rawValue: AnySendable

  init() {
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

#if canImport(Observation)
  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  extension ObservationRegistrarWrapper {
    init(rawValue: ObservationRegistrar) {
      self._rawValue = AnySendable(rawValue)
    }

    var rawValue: ObservationRegistrar {
      self._rawValue.base as! ObservationRegistrar
    }

    func access<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.rawValue.access(subject, keyPath: keyPath)
    }

    func willSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.rawValue.willSet(subject, keyPath: keyPath)
    }

    func didSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.rawValue.didSet(subject, keyPath: keyPath)
    }

    func withMutation<Subject: Observable, Member, T>(
      of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
    ) rethrows -> T {
      try self.rawValue.withMutation(of: subject, keyPath: keyPath, mutation)
    }
  }
#endif
