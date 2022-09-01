import Combine
import CustomDump
import SwiftUI

/// A structure that transforms a store into an observable view store in order to compute views from
/// store state.
public struct WithViewStore<State, Action, Content> {
  private let content: (Store<State, Action>, _ prefix: String?) -> Content
  let store: Store<State, Action>

  #if DEBUG
    private var prefix: String?
  #endif

  fileprivate init(
    store: Store<State, Action>,
    content: @escaping (Store<State, Action>, _ prefix: String?) -> Content
  ) {
    self.content = content
    self.store = store
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

  public var body: Content {
    return self.content(self.store, self.prefix)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
public struct _StateObjectViewStore<State, Action, Content> {
  @StateObject var viewStore: ViewStore<State, Action>
  let content: (ViewStore<State, Action>) -> Content

  #if DEBUG
    private let file: StaticString
    private let line: UInt
    private var prefix: String?
    private var previousState: (State) -> State?
  #endif

  init(
    viewStore: @autoclosure @escaping () -> ViewStore<State, Action>,
    content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString,
    line: UInt,
    prefix: String? = nil
  ) {
    self._viewStore = .init(wrappedValue: viewStore())
    self.content = content
    self.file = file
    self.line = line
    self.prefix = prefix
    var previousState: State? = nil
    self.previousState = { currentState in
      defer { previousState = currentState }
      return previousState
    }
  }

  public var body: Content {
    #if DEBUG
      debugPrint(
        prefix: self.prefix,
        state: self.viewStore.state,
        previousState: self.previousState(self.viewStore.state),
        action: Action.self
      )
    #endif
    return self.content(ViewStore(self.viewStore))
  }
}

public struct _ObservedObjectViewStore<State, Action, Content> {
  @ObservedObject var viewStore: ViewStore<State, Action>
  let content: (ViewStore<State, Action>) -> Content

  #if DEBUG
    private let file: StaticString
    private let line: UInt
    private var prefix: String?
    private var previousState: (State) -> State?
  #endif

  init(
    viewStore: ViewStore<State, Action>,
    content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString,
    line: UInt,
    prefix: String? = nil
  ) {
    self.viewStore = viewStore
    self.content = content
    self.file = file
    self.line = line
    self.prefix = prefix
    var previousState: State? = nil
    self.previousState = { currentState in
      defer { previousState = currentState }
      return previousState
    }
  }

  public var body: Content {
    #if DEBUG
      debugPrint(
        prefix: self.prefix,
        state: self.viewStore.state,
        previousState: self.previousState(self.viewStore.state),
        action: Action.self
      )
    #endif
    return self.content(ViewStore(self.viewStore))
  }
}

// MARK: - View

extension WithViewStore: View where Content: View {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  )
  where Content == _ConditionalContent<AnyView, _ObservedObjectViewStore<State, Action, _Content>> {
    self.init(
      store: store,
      content: { store, prefix in
        if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, *) {
          return ViewBuilder.buildEither(
            first: AnyView(
              _StateObjectViewStore(
                viewStore: ViewStore(store, removeDuplicates: isDuplicate),
                content: content,
                file: file,
                line: line,
                prefix: prefix
              )
            )
          )
        } else {
          return ViewBuilder.buildEither(
            second: _ObservedObjectViewStore(
              viewStore: ViewStore(store, removeDuplicates: isDuplicate),
              content: content,
              file: file,
              line: line,
              prefix: prefix
            )
          )
        }
      }
    )
  }
}

extension WithViewStore where State: Equatable, Content: View {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  )
  where Content == _ConditionalContent<AnyView, _ObservedObjectViewStore<State, Action, _Content>> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

extension WithViewStore where State == Void, Content: View {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  )
  where Content == _ConditionalContent<AnyView, _ObservedObjectViewStore<State, Action, _Content>> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

extension WithViewStore: DynamicViewContent where State: Collection, Content: DynamicViewContent {
  public typealias Data = State

  public var data: State {
    self.store.state.value
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension _StateObjectViewStore: View where Content: View {
  @_disfavoredOverload
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore(),
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

extension _ObservedObjectViewStore: View where Content: View {
  @_disfavoredOverload
  init(
    viewStore: ViewStore<State, Action>,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore,
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

// MARK: - AccessibilityRotorContent

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension WithViewStore: AccessibilityRotorContent where Content: AccessibilityRotorContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute accessibility rotor content from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(
      store: store,
      content: { store, prefix in
        _StateObjectViewStore(
          viewStore: ViewStore(store, removeDuplicates: isDuplicate),
          content: content,
          file: file,
          line: line,
          prefix: prefix
        )
      }
    )
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension WithViewStore where State: Equatable, Content: AccessibilityRotorContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute accessibility rotor content from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension WithViewStore where State == Void, Content: AccessibilityRotorContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute accessibility rotor content from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension _StateObjectViewStore: AccessibilityRotorContent
where Content: AccessibilityRotorContent {
  @_disfavoredOverload
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore(),
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension _ObservedObjectViewStore: AccessibilityRotorContent
where Content: AccessibilityRotorContent {
  @_disfavoredOverload
  fileprivate init(
    viewStore: ViewStore<State, Action>,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore,
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

// MARK: - Commands

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension WithViewStore: Commands where Content: Commands {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute commands from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(
      store: store,
      content: { store, prefix in
        _StateObjectViewStore(
          viewStore: ViewStore(store, removeDuplicates: isDuplicate),
          content: content,
          file: file,
          line: line,
          prefix: prefix
        )
      }
    )
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension WithViewStore where State: Equatable, Content: Commands {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute commands from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension WithViewStore where State == Void, Content: Commands {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute commands from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension _StateObjectViewStore: Commands where Content: Commands {
  @_disfavoredOverload
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore(),
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension _ObservedObjectViewStore: Commands where Content: Commands {
  @_disfavoredOverload
  fileprivate init(
    viewStore: ViewStore<State, Action>,
    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore,
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

// MARK: - Scene

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore: Scene where Content: Scene {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute scenes from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(
      store: store,
      content: { store, prefix in
        _StateObjectViewStore(
          viewStore: ViewStore(store, removeDuplicates: isDuplicate),
          content: content,
          file: file,
          line: line,
          prefix: prefix
        )
      }
    )
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
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore where State == Void, Content: Scene {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute scenes from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension _StateObjectViewStore: Scene where Content: Scene {
  @_disfavoredOverload
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore(),
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension _ObservedObjectViewStore: Scene where Content: Scene {
  @_disfavoredOverload
  fileprivate init(
    viewStore: ViewStore<State, Action>,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore,
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

// MARK: - ToolbarContent

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore: ToolbarContent where Content: ToolbarContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute toolbar content from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(
      store: store,
      content: { store, prefix in
        _StateObjectViewStore(
          viewStore: ViewStore(store, removeDuplicates: isDuplicate),
          content: content,
          file: file,
          line: line,
          prefix: prefix
        )
      }
    )
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore where State: Equatable, Content: ToolbarContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute toolbar content from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension WithViewStore where State == Void, Content: ToolbarContent {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute toolbar content from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<_Content>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> _Content
  ) where Content == _StateObjectViewStore<State, Action, _Content> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension _StateObjectViewStore: ToolbarContent where Content: ToolbarContent {
  @_disfavoredOverload
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore(),
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension _ObservedObjectViewStore: ToolbarContent where Content: ToolbarContent {
  @_disfavoredOverload
  fileprivate init(
    viewStore: ViewStore<State, Action>,
    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore: viewStore,
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

#if DEBUG
  private func debugPrint<State, Action>(
    prefix: String?,
    state: State,
    previousState: State?,
    action: Action.Type,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    if let prefix = prefix {
      var stateDump = ""
      customDump(state, to: &stateDump, indent: 2)
      let difference =
        previousState
        .map {
          diff($0, state).map { "(Changed state)\n\($0)" }
            ?? "(No difference in state detected)"
        }
        ?? "(Initial state)\n\(stateDump)"
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
        @\(file):\(line) \(difference)
        """
      )
    }
  }
#endif
