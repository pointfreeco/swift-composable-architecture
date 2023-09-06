#if swift(>=5.9) && canImport(Observation)
  import Foundation
  import Observation
  import SwiftUI

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  public protocol ObservableState {
    var _$id: StateID { get }
  }

  public struct StateID: Equatable, Hashable, Identifiable, Sendable {
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

  // TODO: make Sendable
  public struct ObservationRegistrarWrapper {
    private let _rawValue: Any

    public init() {
      if #available(iOS 17, *) {
        self._rawValue = ObservationRegistrar()
      } else {
        self._rawValue = ()
      }
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
    internal var observedState: State {
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

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  extension Store where State: ObservableState {
    private(set) public var state: State {
      get { self.observedState }
      set { self.observedState = newValue }
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
      self.state[keyPath: keyPath]
    }

    public func binding<Value>(
      get: @escaping (_ state: State) -> Value,
      send valueToAction: @escaping (_ value: Value) -> Action
    ) -> Binding<Value> {
      ObservedObject(wrappedValue: self)
        .projectedValue[get: .init(rawValue: get), send: .init(rawValue: valueToAction)]
    }

    private subscript<Value>(
      get fromState: HashableWrapper<(State) -> Value>,
      send toAction: HashableWrapper<(Value) -> Action?>
    ) -> Value {
      get { fromState.rawValue(self.state) }
      set {
        BindingLocal.$isActive.withValue(true) {
          if let action = toAction.rawValue(newValue) {
            self.send(action)
          }
        }
      }
    }
  }

  private struct HashableWrapper<Value>: Hashable {
    let rawValue: Value
    static func == (lhs: Self, rhs: Self) -> Bool { false }
    func hash(into hasher: inout Hasher) {}
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  extension Store: ObservableObject where State: ObservableState {}

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  public func isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
    guard let lhs = lhs as? any ObservableState, let rhs = rhs as? any ObservableState
    else {
      return true
    }
    return lhs._$id.id == rhs._$id.id
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

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  extension Optional: ObservableState where Wrapped: ObservableState {
    public var _$id: ComposableArchitecture.StateID {
      self?._$id ?? StateID(uuid: [])
    }
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  extension PresentationState: ObservableState where State: ObservableState {
    public var _$id: ComposableArchitecture.StateID {
      self.wrappedValue._$id
    }
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  extension StackState: ObservableState where Element: ObservableState {
    public var _$id: ComposableArchitecture.StateID {
      .init(uuid: self.flatMap { $0._$id.uuid })
    }
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  extension Binding {
    public subscript<State: ObservableState, Action: BindableAction, Member: Equatable>(
      dynamicMember keyPath: WritableKeyPath<State, Member>
    ) -> Binding<Member>
    where Value == Store<State, Action>, Action.State == State {
      Binding<Member>(
        get: { self.wrappedValue.state[keyPath: keyPath] },
        set: { self.transaction($1).wrappedValue.send(.binding(.set(keyPath, $0))) }
      )
    }

//    public subscript<State, Action: ViewAction, Member>(
//      dynamicMember keyPath: WritableKeyPath<State, Member>
//    ) -> Binding<Member>
//    where Value == Store<State, Action>, Action.ViewAction: BindableAction<State> {
//      Binding<Member>(
//        get: { self.wrappedValue.state[keyPath: keyPath] },
//        set: { self.transaction($1).wrappedValue.send(.view(.binding(.set(keyPath, $0)))) }
//      )
//    }
  }

#endif
