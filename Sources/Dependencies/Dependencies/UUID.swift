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
  ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
  ///     switch action {
  ///     case .create:
  ///       state.append(Todo(id: self.uuid())
  ///       return .none
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// By default, a "live" generator is supplied, which returns a random UUID when called by
  /// invoking `UUID.init` under the hood.  When used from a `TestStore`, an "unimplemented"
  /// generator that additionally reports test failures is supplied, unless explicitly overridden.
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
    static let liveValue = UUIDGenerator { UUID() }
    static let testValue = UUIDGenerator {
      XCTFail(#"Unimplemented: @Dependency(\.uuid)"#)
      return UUID()
    }
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

  /// Initializes a UUID generator that generates a UUID from a closure.
  ///
  /// - Parameter generate: A closure that returns the current date when called.
  public init(_ generate: @escaping @Sendable () -> UUID) {
    self.generate = generate
  }

  public func callAsFunction() -> UUID {
    self.generate()
  }
}

private final class IncrementingUUIDGenerator: @unchecked Sendable {
  private let lock = NSLock()
  private var sequence = 0

  func callAsFunction() -> UUID {
    self.lock.lock()
    defer {
      self.sequence += 1
      self.lock.unlock()
    }
    return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", self.sequence))")!
  }
}
