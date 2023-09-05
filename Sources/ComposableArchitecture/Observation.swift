#if swift(>=5.9) && canImport(Observation)
  import Foundation
  import Observation

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  public protocol ObservableState: Observable {
    var _$id: StateID { get }
  }

  public struct StateID: Equatable, Hashable, Identifiable {
    public var id: AnyHashable {
      self.uuid
    }
    // TODO: Make the comparable token/logic opaque
    public let uuid: [UUID]
    init(uuid: [UUID]) {
      self.uuid = uuid
    }
    public init() {
      self.uuid = [UUID()]
    }

    // TODO: should we do this to prevent us from accidentally comparing == of two StateIDs?
    @available(*, deprecated, message: "Use the 'id' property of StateID to check for equality.")
    public static func == (_: Self, _: Self) -> Bool {
      true
    }
    @available(*, deprecated, message: "Use the 'id' property of StateID to check for inequality.")
    public static func != (_: Self, _: Self) -> Bool {
      false
    }
  }

  extension StateID: CustomDebugStringConvertible {
    public var debugDescription: String {
      ""
    }
  }

  public struct ObservationRegistrarWrapper {
    private let _rawValue: Any

    public init() {
      self._rawValue = ()
    }

    @available(iOS, introduced: 17)
    @available(macOS, introduced: 14)
    @available(tvOS, introduced: 17)
    @available(watchOS, introduced: 10)
    public init(rawValue: ObservationRegistrar) {
      self._rawValue = rawValue
    }

    @available(iOS, introduced: 17)
    @available(macOS, introduced: 14)
    @available(tvOS, introduced: 17)
    @available(watchOS, introduced: 10)
    public var rawValue: ObservationRegistrar {
      self._rawValue as! ObservationRegistrar
    }
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  extension Store: Observable {

    public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
      self.state[keyPath: keyPath]
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

    private(set) public var state: State {
      get {
        self.access(keyPath: \.state)
        return self.subject.value
      }
      set {
        if isIdentityEqual(self.subject.value, newValue) {
          self.subject.value = newValue
        } else {
          self.withMutation(keyPath: \.state) {
            self.subject.value = newValue
          }
        }
      }
    }
  }


  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  func isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
    guard let lhs = lhs as? any ObservableState, let rhs = rhs as? any ObservableState
    else { return true }
    return lhs._$id.id == rhs._$id.id
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  public struct ObservationStateRegistrar: Equatable, Hashable {
    public let id = StateID()
    public let _$observationRegistrar = ObservationRegistrar()
    public init() {
    }

    public func access<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) where Subject: ObservableState {
      self._$observationRegistrar.access(subject, keyPath: keyPath)
    }

    public func willSet<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) where Subject : ObservableState {
      self._$observationRegistrar.willSet(subject, keyPath: keyPath)
    }

    public func didSet<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) where Subject : ObservableState {
      self._$observationRegistrar.didSet(subject, keyPath: keyPath)
    }

    public func withMutation<Subject, Member, T>(of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T) rethrows -> T where Subject : ObservableState {
      try self._$observationRegistrar.withMutation(of: subject, keyPath: keyPath, mutation)
    }
  }
#endif
