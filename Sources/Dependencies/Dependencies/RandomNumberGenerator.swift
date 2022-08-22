import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// A dependency that yields a random number generator to a closure.
  ///
  /// Introduce controllable randomness to your reducer by using the ``Dependency`` property wrapper
  /// with a key path to this property. The wrapped value is an instance of
  /// ``WithRandomNumberGenerator``, which can be called with a closure to yield a random number
  /// generator. (It can be called directly because it defines
  /// ``WithRandomNumberGenerator/callAsFunction(_:)``, which is called when you invoke the instance
  /// as you would invoke a function.)
  ///
  /// For example, you could introduce controllable randomness to a reducer that models rolling a
  /// couple dice:
  ///
  /// ```
  /// struct DiceRollReducer: ReducerProtocol {
  ///   struct State {
  ///     var die1: Int = 1
  ///     var die2: Int = 1
  ///   }
  ///
  ///   enum Action {
  ///     case roll
  ///   }
  ///
  ///   @Dependency(\.withRandomNumberGenerator) var withRandomNumberGenerator
  ///
  ///   func reduce(into state: inout State, action: Action) -> Effect<Action> {
  ///     switch action {
  ///     case .roll:
  ///       self.withRandomNumberGenerator { generator in
  ///         state.die1 = Int.random(in: 1...6, using: &generator)
  ///         state.die2 = Int.random(in: 1...6, using: &generator)
  ///       }
  ///       return .none
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// By default, a `SystemRandomNumberGenerator` will be provided to the closure, with the
  /// exception of a ``TestStore``, in which a "failing" dependency will be provided.
  ///
  /// To test a reducer that depends on randomness, you can override its random number generator
  /// using ``Reducer/dependency(_:_:)``. Inject a dependency by calling
  /// ``WithRandomNumberGenerator/init(_:)`` with a random number generator that offers predictable
  /// randomness. For example, you could test the dice-rolling reducer by supplying a seeded random
  /// number generator as a dependency:
  ///
  /// ```
  /// let store = TestStore(
  ///   initialState: DiceRollReducer.State()
  ///   reducer: DiceRollReducer()
  ///     .dependency(\.withRandomNumberGenerator, .init(LCRNG(seed: 0)))
  /// )
  ///
  /// store.send(.roll) {
  ///   $0.die1 = 1
  ///   $0.die2 = 3
  /// }
  /// ```
  public var withRandomNumberGenerator: WithRandomNumberGenerator {
    get { self[WithRandomNumberGeneratorKey.self] }
    set { self[WithRandomNumberGeneratorKey.self] = newValue }
  }

  private enum WithRandomNumberGeneratorKey: LiveDependencyKey {
    static let liveValue = WithRandomNumberGenerator(SystemRandomNumberGenerator())
    static let testValue = WithRandomNumberGenerator(UnimplementedRandomNumberGenerator())
  }
}

/// A dependency that yields a random number generator to a closure.
///
/// Introduce controllable randomness to your reducer by using the ``Dependency`` property wrapper
/// with a key path to this value via ``DependencyValues/withRandomNumberGenerator``. This value can
/// be called with a closure that yields a random number generator. (It can be called directly
/// because it defines ``callAsFunction(_:)``, which is called when you invoke the value as you
/// would invoke a function.)
///
/// For example, you could introduce testable randomness to a reducer that models rolling a couple
/// dice:
///
/// ```
/// struct DiceRollReducer: ReducerProtocol {
///   struct State {
///     var die1: Int = 1
///     var die2: Int = 1
///   }
///
///   enum Action {
///     case roll
///   }
///
///   @Dependency(\.withRandomNumberGenerator) var withRandomNumberGenerator
///
///   func reduce(into state: inout State, action: Action) -> Effect<Action> {
///     switch action {
///     case .roll:
///       self.withRandomNumberGenerator { generator in
///         state.die1 = Int.random(in: 1...6, using: &generator)
///         state.die2 = Int.random(in: 1...6, using: &generator)
///       }
///       return .none
///     }
///   }
/// }
/// ```
///
/// By default, a `SystemRandomNumberGenerator` will be provided to the closure, with the exception
/// of a ``TestStore``, in which a "failing" dependency will be provided.
///
/// To test a reducer that depends on randomness, you can override its random number generator
/// using ``ReducerProtocol/dependency(_:_:)``. Inject a dependency by calling ``init(_:)`` with a random
/// number generator that offers predictable randomness. For example, you could test the
/// dice-rolling reducer by supplying a seeded random number generator as a dependency:
///
/// ```
/// let store = TestStore(
///   initialState: DiceRollReducer.State()
///   reducer: DiceRollReducer()
///     .dependency(\.withRandomNumberGenerator, .init(LCRNG(seed: 0)))
/// )
///
/// store.send(.roll) {
///   $0.die1 = 1
///   $0.die2 = 3
/// }
/// ```
public final class WithRandomNumberGenerator: @unchecked Sendable {
  private var generator: RandomNumberGenerator
  private let lock: os_unfair_lock_t

  public init<T: RandomNumberGenerator & Sendable>(_ generator: T) {
    self.generator = generator
    self.lock = os_unfair_lock_t.allocate(capacity: 1)
    self.lock.initialize(to: os_unfair_lock())
  }

  deinit {
    self.lock.deinitialize(count: 1)
    self.lock.deallocate()
  }

  public func callAsFunction<R>(_ work: (inout RandomNumberGenerator) -> R) -> R {
    os_unfair_lock_lock(self.lock)
    defer { os_unfair_lock_unlock(self.lock) }
    return work(&self.generator)
  }
}

private struct UnimplementedRandomNumberGenerator: RandomNumberGenerator {
  var generator = SystemRandomNumberGenerator()

  mutating func next() -> UInt64 {
    XCTFail(#"Unimplemented: @Dependency(\.withRandomNumberGenerator)"#)
    return generator.next()
  }
}
