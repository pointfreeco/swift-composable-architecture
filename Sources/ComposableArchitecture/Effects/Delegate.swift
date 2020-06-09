import Combine
import Foundation

/// Whenever you're trying to fit an existing delegate protocol into the Combosable Architecture, you can opt to conform it to this protocol as well.
/// When you do, for every delegate method you need to hook up to the architecture, just call `subscriber?.send()`
///  with the action you need to pass into your store.
///
/// For instance, if you need to implement UISearchBarDelegate and pass its calls into your store, you can do this:
///
/// ```
/// enum MySearchAction {
///   case textDidChange(String)
///   // etc...
/// }
///
/// class SearchBarDelegate: NSObject, UISearchBarDelegate, EffectDelegate {
///   var subscriber: Effect<MySearchAction, Never>.Subscriber?
///
///   func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
///     subscriber?.send(.textDidChange(searchText))
///   }
///
///   // etc...
/// }
/// ```
///
/// Once this is done, you just have to call
/// ```
/// Effect.from(delegate:)
/// ```
///  to create an effect for your delegate that can feed values to your store.
public protocol EffectDelegate: AnyObject {
  associatedtype Output

  var subscriber: Effect<Output, Never>.Subscriber? { get set }
}

extension Effect {

  /// Creates an effect from the given `EffectDelegate`, which (given that the `EffectDelegate` implementation is written correctly) will emit values whenever the delegate's methods are called.
  ///
  /// - Parameters:
  ///   - delegate: The delegate to build an effect from.
  ///   - onCancel: An optional closure to provide any cleanup behavior you wish when the effect is cancelled.
  /// - Returns: A new `Effect` that will send values for any of the given delegate's callbacks.
  public static func fromDelegate<Delegate: EffectDelegate>(
    _ delegate: Delegate,
    onCancel: @escaping () -> Void = {}
  ) -> Effect<Output, Failure>
    where Effect.Output == Delegate.Output, Effect.Failure == Never
  {
    Effect.run { subscriber in
      delegate.subscriber = subscriber
      return AnyCancellable {
        delegate.subscriber = nil
        onCancel()
      }
    }
  }

  /// Creates an effect from the given `EffectDelegate`, which (given that the `EffectDelegate` implementation is written correctly) will emit values whenever the delegate's methods are called.
  ///
  /// - Parameters:
  ///   - onCreate: A closure that must return the delegate you wish to create an effect from.
  ///   - onCancel: An optional closure to provide any cleanup behavior you wish when the effect is cancelled.
  /// - Returns: A new `Effect` that will send values for any of the given delegate's callbacks.
  public static func fromDelegate<Delegate: EffectDelegate>(
    onCreate createDelegate: @escaping (Effect<Delegate.Output, Never>.Subscriber) -> Delegate,
    onCancel: @escaping () -> Void = {}
  ) -> Effect<Output, Failure>
    where Effect.Output == Delegate.Output, Effect.Failure == Never
  {
    Effect.run { subscriber in
      let delegate = createDelegate(subscriber)
      delegate.subscriber = subscriber
      return AnyCancellable {
        delegate.subscriber = nil
        onCancel()
      }
    }
  }
}
