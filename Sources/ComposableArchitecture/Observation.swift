import Foundation

public protocol ObservableState {
  var _$id: StateID { get }
}

public struct StateID: Equatable, Hashable, Sendable {
  private let uuid: UUID
  public var id: AnyHashable {
    self.uuid
  }
  public init() {
    self.uuid = UUID()
  }
}
extension StateID: CustomDebugStringConvertible {
  public var debugDescription: String {
    "StateID(\(self.uuid.description))"
  }
}

extension Store: Observable {
  var observedState: State {
    get {
      self.access(keyPath: \.observedState)
      return self.subject.value
    }
    set {
      if isIdentityEqual(self.subject.value, newValue) {
        self.subject.value = newValue
      } else {
        self.withMutation(keyPath: \.observedState) {
          self.subject.value = newValue
        }
      }
    }
  }

  internal nonisolated func access<Member>(keyPath: KeyPath<Store, Member>) {
    _$observationRegistrar.access(self, keyPath: keyPath)
  }

  internal nonisolated func withMutation<Member, T>(
    keyPath: KeyPath<Store, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
  }
}

extension Store where State: ObservableState {
  private(set) public var state: State {
    get { self.observedState }
    set { self.observedState = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}

@available(iOS, introduced: 17)
@available(macOS, introduced: 14)
@available(tvOS, introduced: 17)
@available(watchOS, introduced: 10)
public func isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  if
    let oldID = (lhs as? any ObservableState)?._$id,
    let newID = (rhs as? any ObservableState)?._$id
  {
    return oldID.id == newID.id
  } else {

    func open<C: Collection>(_ lhs: C, _ rhs: Any) -> Bool {
      let rhs = rhs as! C
      return lhs.count == rhs.count
      && zip(lhs, rhs).allSatisfy(isIdentityEqual)
    }

    if
      let lhs = lhs as? any Collection
    {
      return open(lhs, rhs)
    }

    return false
  }
}

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
