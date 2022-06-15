import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// A dependency that generates UUIDs.
  ///
  /// Introduce controllable UUID generation to your reducer by using the ``Dependency`` property
  /// wrapper with a key path to this property. The wrapped value is an instance of
  /// ``UUIDGenerator``, which can be called with a closure to create UUIDs. (It can be called
  /// directly because it defines ``UUIDGenerator/callAsFunction()``, which is called when you
  /// invoke the instance as you would invoke a function.)
  ///
  /// For example, you could introduce controllable UUID generation to a reducer that creates to-dos
  /// with unique identifiers:
  ///
  /// ```
  /// struct Todo: Identifiable {
  ///   let id: UUID
  ///   var description: String = ""
  /// }
  ///
  /// struct TodosReducer: ReducerProtocol {
  ///   struct State {
  ///     var todos: IdentifiedArrayOf<Todo> = []
  ///   }
  ///
  ///   enum Action {
  ///     case create
  ///   }
  ///
  ///   @Dependency(\.uuid) var uuid
  ///
  ///   func reduce(into state: inout State, action: Action) -> Effect<Action> {
  ///     switch action {
  ///     case .create:
  ///       state.append(Todo(id: self.uuid())
  ///       return .none
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// By default, a ``LiveUUIDGenerator`` is supplied, which returns a random UUID when called by
  /// invoking `UUID.init` under the hood.  When used from a ``TestStore``, a
  /// ``FailingUUIDGenerator`` is supplied, which additionally calls `XCTFail` when invoked.
  ///
  /// To test a reducer that depends on UUID generation, you can override its generator using
  /// ``Reducer/dependency(_:_:)`` to override the underlying ``UUIDGenerator``:
  ///
  ///   * ``UUIDGenerator/incrementing`` for reproducible UUIDs that count up from
  ///     `00000000-0000-0000-0000-000000000000`.
  ///
  ///   * ``UUIDGenerator/constant(_:)`` for a generator that always returns the given UUID.
  ///
  /// For example, you could test the to-do-creating reducer by supplying an
  /// ``IncrementingUUIDGenerator`` as a dependency:
  ///
  /// ```
  /// let store = TestStore(
  ///   initialState: .init()
  ///   reducer: TodosReducer()
  ///     .dependency(\.uuid, .incrementing)
  /// )
  ///
  /// store.send(.create) {
  ///   $0.todos = [
  ///     .init(id: UUID(string: "00000000-000-0000-0000-000000000000")!)
  ///   ]
  /// }
  /// ```
  public var uuid: any UUIDGenerator {
    get { self[UUIDGeneratorKey.self] }
    set { self[UUIDGeneratorKey.self] = newValue }
  }

  private enum UUIDGeneratorKey: LiveDependencyKey {
    static let liveValue: any UUIDGenerator = LiveUUIDGenerator()
    static let testValue: any UUIDGenerator = FailingUUIDGenerator()
  }
}

public protocol UUIDGenerator: Sendable {
  func callAsFunction() -> UUID
}

public struct LiveUUIDGenerator: UUIDGenerator {
  public init() {}

  public func callAsFunction() -> UUID {
    .init()
  }
}

extension UUIDGenerator where Self == LiveUUIDGenerator {
  public static var live: Self { .init() }
}

public struct FailingUUIDGenerator: UUIDGenerator {
  public init() {}

  public func callAsFunction() -> UUID {
    XCTFail(#"@Dependency(\.uuid) is failing"#)
    return .init()
  }
}

extension UUIDGenerator where Self == FailingUUIDGenerator {
  public static var failing: Self { .init() }
}

public final class IncrementingUUIDGenerator: UUIDGenerator, @unchecked Sendable {
  private let lock: os_unfair_lock_t
  private var sequence = 0

  public init() {
    self.lock = os_unfair_lock_t.allocate(capacity: 1)
    self.lock.initialize(to: os_unfair_lock())
  }

  deinit {
    self.lock.deinitialize(count: 1)
    self.lock.deallocate()
  }

  public func callAsFunction() -> UUID {
    self.lock.sync {
      defer { self.sequence += 1 }
      return .init(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", self.sequence))")!
    }
  }
}

extension UUIDGenerator where Self == IncrementingUUIDGenerator {
  public static var incrementing: Self { .init() }
}

public struct ConstantUUIDGenerator: UUIDGenerator {
  public let value: UUID

  public init(_ value: UUID) {
    self.value = value
  }

  public func callAsFunction() -> UUID {
    self.value
  }
}

extension UUIDGenerator where Self == ConstantUUIDGenerator {
  public static func constant(_ uuid: UUID) -> Self { .init(uuid) }
}
