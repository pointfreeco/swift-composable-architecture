import SwiftUI

/// A structure that transforms a store into an observable view store in order to compute scenes from
/// store state.
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct SceneWithViewStore<State, Action, Content>: Scene where Content: Scene {
  private let content: (ViewStore<State, Action>) -> Content
  private var prefix: String?
  @ObservedObject private var viewStore: ViewStore<State, Action>

  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute scenes from store state.

  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.content = content
    self.viewStore = ViewStore(store, removeDuplicates: isDuplicate)
  }

  public var body: some Scene {
    #if DEBUG
      if let prefix = self.prefix {
        print(
          """
          \(prefix.isEmpty ? "" : "\(prefix): ")\
          Evaluating WithViewStore<\(State.self), \(Action.self), ...>.body
          """
        )
      }
    #endif
    return self.content(self.viewStore)
  }

  /// Prints debug information to the console whenever the view is computed.
  ///
  /// - Parameter prefix: A string with which to prefix all debug messages.
  /// - Returns: A structure that prints debug messages for all computations.
  public func debug(_ prefix: String = "") -> Self {
    var view = self
    view.prefix = prefix
    return view
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension SceneWithViewStore where State: Equatable {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, content: content)
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension SceneWithViewStore where State == Void {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, content: content)
  }
}
