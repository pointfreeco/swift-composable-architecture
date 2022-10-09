import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// A dependency that generates UUIDs.
  ///
  /// Introduce controllable UUID generation to your features by using the ``Dependency`` property
  /// wrapper with a key path to this property. The wrapped value is an instance of
  /// ``UUIDGenerator``, which can be called with a closure to create UUIDs. (It can be called
  /// directly because it defines ``UUIDGenerator/callAsFunction()``, which is called when you
  /// invoke the instance as you would invoke a function.)
  ///
  /// For example, you could introduce controllable UUID generation to a reducer that creates to-dos
  /// with unique identifiers:
  ///
  /// ```swift
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
  /// By default, a ``UUIDGenerator/live`` generator is supplied, which returns a random UUID when
  /// called by invoking `UUID.init` under the hood.  When used from a `TestStore`, an
  /// ``UUIDGenerator/unimplemented`` generator is supplied, which additionally calls `XCTFail` when
  /// invoked.
  ///
  /// To test a reducer that depends on UUID generation, you can override its generator using the
  /// `Reducer/dependency(_:_:)` modifier to override the underlying ``UUIDGenerator``:
  ///
  ///   * ``UUIDGenerator/incrementing`` for reproducible UUIDs that count up from
  ///     `00000000-0000-0000-0000-000000000000`.
  ///
  ///   * ``UUIDGenerator/constant(_:)`` for a generator that always returns the given UUID.
  ///
  /// For example, you could test the to-do-creating reducer by supplying an
  /// ``UUIDGenerator/incrementing`` generator as a dependency:
  ///
  /// ```swift
  /// let store = TestStore(
  ///   initialState: Todos.State()
  ///   reducer: Todos()
  /// )
  ///
  /// store.dependencies.uuid = .incrementing
  ///
  /// store.send(.create) {
  ///   $0.todos = [
  ///     Todo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
  ///   ]
  /// }
  /// ```
  public var uuid: UUIDGenerator {
    get { self[UUIDGeneratorKey.self] }
    set { self[UUIDGeneratorKey.self] = newValue }
  }

  private enum UUIDGeneratorKey: DependencyKey {
    static let liveValue: UUIDGenerator = .live
    static let testValue: UUIDGenerator = .unimplemented
  }
}

/// A dependency that generates a UUID.
///
/// See ``DependencyValues/uuid`` for more information.
public struct UUIDGenerator: Sendable {
  private let generate: @Sendable () -> UUID

  /// A generator that returns a constant UUID.
  ///
  /// - Parameter uuid: A UUID to return.
  /// - Returns: A generator that always returns the given UUID.
  public static func constant(_ uuid: UUID) -> Self {
    Self { uuid }
  }

  /// A generator that generates UUIDs in incrementing order.
  ///
  /// For example:
  ///
  /// ```swift
  /// let generate = UUIDGenerator.incrementing
  /// generate()  // UUID(00000000-0000-0000-0000-000000000000)
  /// generate()  // UUID(00000000-0000-0000-0000-000000000001)
  /// generate()  // UUID(00000000-0000-0000-0000-000000000002)
  /// ```
  public static var incrementing: Self {
    let generator = IncrementingUUIDGenerator()
    return Self { generator() }
  }

  /// A generator that calls `UUID()` under the hood.
  public static let live = Self { UUID() }

  /// A generator that calls `XCTFail` when it is invoked.
  public static let unimplemented = Self {
    XCTFail(#"Unimplemented: @Dependency(\.uuid)"#)
    return UUID()
  }

  public func callAsFunction() -> UUID {
    self.generate()
  }
}

private final class IncrementingUUIDGenerator: @unchecked Sendable {
  private let lock: os_unfair_lock_t
  private var sequence = 0

  init() {
    self.lock = os_unfair_lock_t.allocate(capacity: 1)
    self.lock.initialize(to: os_unfair_lock())
  }

  deinit {
    self.lock.deinitialize(count: 1)
    self.lock.deallocate()
  }

  func callAsFunction() -> UUID {
    os_unfair_lock_lock(self.lock)
    defer {
      self.sequence += 1
      os_unfair_lock_unlock(self.lock)
    }
    return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", self.sequence))")!
  }
}
