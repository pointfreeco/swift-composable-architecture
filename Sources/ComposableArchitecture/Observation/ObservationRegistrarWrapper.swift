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
  private var rawValue: ObservationRegistrar {
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

extension ObservationRegistrarWrapper {
  // TODO: Rename to something else
  private var rawValue2: TCAObservationRegistrar {
    self._rawValue.base as! TCAObservationRegistrar
  }

  @_disfavoredOverload
  public func access<Subject: TCAObservable, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    #if swift(>=5.9)
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      func `open`<T: Observable>(_ subject: T) {
        // TODO: bitcast worth it?
        if let keyPath = keyPath as? KeyPath<T, Member> {
          self.rawValue.access(subject, keyPath: keyPath)
        }
      }
      if let subject = subject as? any Observable {
        open(subject)
      }
    } else {
      self.rawValue2.access(subject, keyPath: keyPath)
    }
    #endif
  }

  // TODO:
//  @_disfavoredOverload
//  public func willSet<Subject: TCAObservable, Member>(
//    _ subject: Subject, keyPath: KeyPath<Subject, Member>
//  ) {
//    self.rawValue2.willSet(subject, keyPath: keyPath)
//  }
//
//  @_disfavoredOverload
//  public func didSet<Subject: TCAObservable, Member>(
//    _ subject: Subject, keyPath: KeyPath<Subject, Member>
//  ) {
//    self.rawValue2.didSet(subject, keyPath: keyPath)
//  }

  @_disfavoredOverload
  public func withMutation<Subject: TCAObservable, Member, T>(
    of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
  ) rethrows -> T {
    #if swift(>=5.9)
    if 
      #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
      let subject = subject as? any Observable
    {
      func `open`<S: Observable>(_ subject: S) throws -> T {
        // TODO: bitcast worth it?
        let keyPath = keyPath as! KeyPath<S, Member>
        return try self.rawValue.withMutation(of: subject, keyPath: keyPath, mutation)
      }
      return try open(subject)
    } else {
      return try self.rawValue2.withMutation(of: subject, keyPath: keyPath, mutation)
    }
    #else
    return try mutation()
    #endif
  }
}
