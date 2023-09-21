import Foundation

public protocol ObservableState {
  var _$id: StateID { get }
}

public struct StateID: Equatable, Hashable, Sendable {
  private let uuid: UUID
  private var tag: Int?
  public init() {
    self.uuid = UUID()
  }
  public func tagged(_ tag: Int?) -> Self {
    var copy = self
    copy.tag = tag
    return copy
  }
  public static let inert = StateID()
  public static func stateID<T>(for value: T) -> StateID {
    (value as? any ObservableState)?._$id ?? .inert
  }
  public static func stateID(for value: some ObservableState) -> StateID {
    value._$id
  }
}
extension StateID: CustomDebugStringConvertible {
  public var debugDescription: String {
    "StateID(\(self.uuid.description))"
  }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
    _$observationRegistrar.rawValue.access(self, keyPath: keyPath)
  }

  internal nonisolated func withMutation<Member, T>(
    keyPath: KeyPath<Store, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    try _$observationRegistrar.rawValue.withMutation(of: self, keyPath: keyPath, mutation)
  }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension Store where State: ObservableState {
  private(set) public var state: State {
    get { self.observedState }
    set { self.observedState = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}

// TODO: optimize, benchmark
// TODO: Open enums to check isIdentityEqual to avoid requiring `enum State: ObservableState`
@available(iOS, introduced: 17)
@available(macOS, introduced: 14)
@available(tvOS, introduced: 17)
@available(watchOS, introduced: 10)
public func isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  if
    let oldID = (lhs as? any ObservableState)?._$id,
    let newID = (rhs as? any ObservableState)?._$id
  {
    return oldID == newID
  } else {

    func open<C: Collection>(_ lhs: C, _ rhs: Any) -> Bool {
      guard let rhs = rhs as? C else { return false }
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

// TODO: make Sendable
public struct ObservationRegistrarWrapper: Sendable {
  private let _rawValue: AnySendable

  public init() {
    if #available(iOS 17, tvOS 17, watchOS 10, macOS 14, *) {
      self._rawValue = AnySendable(ObservationRegistrar())
    } else {
      self._rawValue = AnySendable(())
    }
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  public init(rawValue: ObservationRegistrar) {
    self._rawValue = AnySendable(rawValue)
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  public var rawValue: ObservationRegistrar {
    self._rawValue.base as! ObservationRegistrar
  }
}
