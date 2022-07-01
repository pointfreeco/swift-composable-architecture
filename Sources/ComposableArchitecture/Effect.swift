import Combine
import Foundation

/// The ``Effect`` type encapsulates a unit of work that can be run in the outside world, and can
/// feed data back to the ``Store``. It is the perfect place to do side effects, such as network
/// requests, saving/loading from disk, creating timers, interacting with dependencies, and more.
///
/// Effects are returned from reducers so that the ``Store`` can perform the effects after the
/// reducer is done running. It is important to note that ``Store`` is not thread safe, and so all
/// effects must receive values on the same thread, **and** if the store is being used to drive UI
/// then it must receive values on the main thread.
///
/// An effect simply wraps a `Publisher` value and provides some convenience initializers for
/// constructing some common types of effects.
public struct Effect<Output, Failure: Error> {
  let publisher: AnyPublisher<Output, Failure>

  /// An effect that does nothing and completes immediately. Useful for situations where you must
  /// return an effect, but you don't need to do anything.
  public static var none: Self {
    Empty(completeImmediately: true).eraseToEffect()
  }

  /// Merges a variadic list of effects together into a single effect, which runs the effects at the
  /// same time.
  ///
  /// - Parameter effects: A list of effects.
  /// - Returns: A new effect
  public static func merge(_ effects: Self...) -> Self {
    .merge(effects)
  }

  /// Merges a sequence of effects together into a single effect, which runs the effects at the same
  /// time.
  ///
  /// - Parameter effects: A sequence of effects.
  /// - Returns: A new effect
  public static func merge<S: Sequence>(_ effects: S) -> Self where S.Element == Effect {
    Publishers.MergeMany(effects).eraseToEffect()
  }

  /// Transforms all elements from the upstream effect with a provided closure.
  ///
  /// - Parameter transform: A closure that transforms the upstream effect's output to a new output.
  /// - Returns: A publisher that uses the provided closure to map elements from the upstream effect
  ///   to new elements that it then publishes.
  public func map<T>(_ transform: @escaping (Output) -> T) -> Effect<T, Failure> {
    .init(self.map(transform) as Publishers.Map<Self, T>)
  }
}
