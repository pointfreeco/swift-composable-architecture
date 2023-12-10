import Perception

// NB: A wrapper around `Observation.ObservationRegistrar` for availability.
struct ObservationRegistrarWrapper: Sendable {
  private let rawValue: PerceptionRegistrar

  init() {
    self.rawValue = PerceptionRegistrar()
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  func access<Subject: Observable, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    self.rawValue.access(subject, keyPath: keyPath)
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  func withMutation<Subject: Observable, Member, T>(
    of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
  ) rethrows -> T {
    try self.rawValue.withMutation(of: subject, keyPath: keyPath, mutation)
  }

  @_disfavoredOverload
  func access<Subject: Perceptible, Member>(
    _ subject: Subject, keyPath: KeyPath<Subject, Member>
  ) {
    self.rawValue.access(subject, keyPath: keyPath)
  }

  @_disfavoredOverload
  func withMutation<Subject: Perceptible, Member, T>(
    of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
  ) rethrows -> T {
    try self.rawValue.withMutation(of: subject, keyPath: keyPath, mutation)
  }
}

extension ObservationRegistrarWrapper: Equatable, Hashable, Codable {
}
