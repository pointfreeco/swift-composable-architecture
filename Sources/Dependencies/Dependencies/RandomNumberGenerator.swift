import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// A dependency that yields a random number generator to a closure.
  ///
  /// Introduce controllable randomness to your features by using the ``Dependency`` property
  /// wrapper with a key path to this property. The wrapped value is an instance of
  /// ``WithRandomNumberGenerator``, which can be called with a closure to yield a random number
  /// generator. (It can be called directly because it defines
  /// ``WithRandomNumberGenerator/callAsFunction(_:)``, which is called when you invoke the instance
  /// as you would invoke a function.)
  ///
  /// For example, you could introduce controllable randomness to a Composable Architecture reducer
  /// that models rolling a couple dice:
  ///
  /// ```swift
  /// struct Game: ReducerProtocol {
  ///   struct State {
  ///     var dice = (1, 1)
  ///   }
  ///
  ///   enum Action {
  ///     case rollDice
  ///   }
  ///
  ///   @Dependency(\.withRandomNumberGenerator) var withRandomNumberGenerator
  ///
  ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
  ///     switch action {
  ///     case .rollDice:
  ///       self.withRandomNumberGenerator { generator in
  ///         state.dice.0 = Int.random(in: 1...6, using: &generator)
  ///         state.dice.1 = Int.random(in: 1...6, using: &generator)
  ///       }
  ///       return .none
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// By default, a `SystemRandomNumberGenerator` will be provided to the closure, with the
  /// exception of a `TestStore`, in which an unimplemented dependency will be provided that calls
  /// `XCTFail`.
  ///
  /// To test a reducer that depends on randomness, you can override its random number generator.
  /// Inject a dependency by calling ``WithRandomNumberGenerator/init(_:)`` with a random number
  /// generator that offers predictable randomness. For example, you could test the dice-rolling of
  /// a game's reducer by supplying a seeded random number generator as a dependency:
  ///
  /// ```swift
  /// let store = TestStore(
  ///   initialState: Game.State()
  ///   reducer: Game()
  /// )
  ///
  /// store.dependencies.withRandomNumberGenerator = WithRandomNumberGenerator(
  ///   LCRNG(seed: 0)
  /// )
  ///
  /// await store.send(.rollDice) {
  ///   $0.dice = (1, 3)
  /// }
  /// ```
  public var withRandomNumberGenerator: WithRandomNumberGenerator {
    get { self[WithRandomNumberGeneratorKey.self] }
    set { self[WithRandomNumberGeneratorKey.self] = newValue }
  }

  private enum WithRandomNumberGeneratorKey: DependencyKey {
    static let liveValue = WithRandomNumberGenerator(SystemRandomNumberGenerator())
    static let testValue = WithRandomNumberGenerator(UnimplementedRandomNumberGenerator())
  }
}

/// A dependency that yields a random number generator to a closure.
///
/// See ``DependencyValues/withRandomNumberGenerator`` for more information.
public final class WithRandomNumberGenerator: @unchecked Sendable {
  private var generator: RandomNumberGenerator
  private let lock = NSLock()

  public init<T: RandomNumberGenerator & Sendable>(_ generator: T) {
    self.generator = generator
  }

  public func callAsFunction<R>(_ work: (inout RandomNumberGenerator) -> R) -> R {
    self.lock.lock()
    defer { self.lock.unlock() }
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
