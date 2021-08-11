import Combine
import SwiftUI

/// A structure that transforms a store into an observable view store in order to compute views from
/// store state.
///
/// Due to a bug in SwiftUI, there are times that use of this view can interfere with some core
/// views provided by SwiftUI. The known problematic views are:
///
///   * If a `GeometryReader` or `ScrollViewReader` is used inside a ``WithViewStore`` it will not
///     receive state updates correctly. To work around you either need to reorder the views so that
///     the `GeometryReader` or `ScrollViewReader` wraps ``WithViewStore``, or, if that is not
///     possible, then you must hold onto an explicit
///     `@ObservedObject var viewStore: ViewStore<State, Action>` in your view in lieu of using this
///     helper (see [here](https://gist.github.com/mbrandonw/cc5da3d487bcf7c4f21c27019a440d18)).
///   * If you create a `Stepper` via the `Stepper.init(onIncrement:onDecrement:label:)` initializer
///     inside a ``WithViewStore`` it will behave erratically. To work around you should use the
///     initializer that takes a binding (see
///     [here](https://gist.github.com/mbrandonw/dee2ceac2c316a1619cfdf1dc7945f66)).
public struct WithViewStore<State, Action, Content> {
  private let content: (ViewStore<State, Action>) -> Content
  #if DEBUG
    private let file: StaticString
    private let line: UInt
    private var prefix: String?
    private var previousState: (State) -> State?
  #endif
  @ObservedObject private var viewStore: ViewStore<State, Action>

  fileprivate init(
    store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.content = content
    #if DEBUG
      self.file = file
      self.line = line
      var previousState: State? = nil
      self.previousState = { currentState in
        defer { previousState = currentState }
        return previousState
      }
    #endif
    self.viewStore = ViewStore(store, removeDuplicates: isDuplicate)
  }

  /// Prints debug information to the console whenever the view is computed.
  ///
  /// - Parameter prefix: A string with which to prefix all debug messages.
  /// - Returns: A structure that prints debug messages for all computations.
  public func debug(_ prefix: String = "") -> Self {
    var view = self
    #if DEBUG
      view.prefix = prefix
    #endif
    return view
  }

  fileprivate var _body: Content {
    #if DEBUG
      if let prefix = self.prefix {
        let difference =
          self.previousState(self.viewStore.state)
          .map {
            debugDiff($0, self.viewStore.state).map { "(Changed state)\n\($0)" }
              ?? "(No difference in state detected)"
          }
          ?? "(Initial state)\n\(debugOutput(self.viewStore.state, indent: 2))"
        func typeName(_ type: Any.Type) -> String {
          var name = String(reflecting: type)
          if let index = name.firstIndex(of: ".") {
            name.removeSubrange(...index)
          }
          return name
        }
        print(
          """
          \(prefix.isEmpty ? "" : "\(prefix): ")\
          WithViewStore<\(typeName(State.self)), \(typeName(Action.self)), _>\
          @\(self.file):\(self.line) \(difference)
          """
        )
      }
    #endif
    return self.content(self.viewStore)
  }
}

extension WithViewStore: View where Content: View {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(
      store: store,
      removeDuplicates: isDuplicate,
      file: file,
      line: line,
      content: content
    )
  }

  public var body: Content {
    self._body
  }
}

extension WithViewStore where State: Equatable, Content: View {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

extension WithViewStore where State == Void, Content: View {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

extension WithViewStore: DynamicViewContent where State: Collection, Content: DynamicViewContent {
  public typealias Data = State

  public var data: State {
    self.viewStore.state
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore: Scene where Content: Scene {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(
      store: store,
      removeDuplicates: isDuplicate,
      file: file,
      line: line,
      content: content
    )
  }

  public var body: Content {
    self._body
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore where State: Equatable, Content: Scene {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute scenes from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore where State == Void, Content: Scene {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute scenes from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}
