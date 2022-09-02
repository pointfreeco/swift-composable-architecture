import Combine
import CustomDump
import SwiftUI

/// A view helper that transforms a ``Store`` into a ``ViewStore`` so that its state can be observed
/// by a view builder.
///
/// This helper is an alternative to observing the view store manually on your view, which requires
/// the boilerplate of a custom initializer.
///
/// For example, the following view, which manually observes the store it is handed by constructing
/// a view store in its initializer:
///
/// ```swift
/// struct ProfileView: View {
///   let store: Store<ProfileState, ProfileAction>
///   @ObservedObject var viewStore: ViewStore<ProfileState, ProfileAction>
///
///   init(store: Store<ProfileState, ProfileAction>) {
///     self.store = store
///     self.viewStore = ViewStore(store)
///   }
///
///   var body: some View {
///     Text("\(self.viewStore.username)")
///     // ...
///   }
/// }
/// ```
///
/// …can be written more simply using `WithViewStore`:
///
/// ```swift
/// struct ProfileView: View {
///   let store: Store<ProfileState, ProfileAction>
///
///   var body: some View {
///     WithViewStore(self.store) { viewStore in
///       Text("\(viewStore.username)")
///       // ...
///     }
///   }
/// }
/// ```
///
/// There may be times where the slightly more verbose style of observing a store is preferred
/// instead of using ``WithViewStore``:
///
/// 1. When ``WithViewStore`` wraps complex views the Swift compiler can quickly become bogged down,
/// leading to degraded compiler performance and diagnostics. If you are experience such instability
/// you should consider manually setting up observation with an `@ObservedObject` property as
/// described above.
///
/// 2. Sometimes you may want to observe the state in a store in a context that is not a view
/// builder. In such cases ``WithViewStore`` will not work since it is intended only for SwiftUI
/// views.
///
///    An example of this is interfacing with SwiftUI's `App` protocol, which uses a separate
///    `@SceneBuilder` instead of `@ViewBuilder`. In this case you must use an `@ObservedObject`:
///
///    ```swift
///    @main
///    struct MyApp: App {
///      let store = Store<AppState, AppAction>(/* ... */)
///      @ObservedObject var viewStore: ViewStore<SceneState, CommandAction>
///
///      struct SceneState: Equatable {
///        // ...
///        init(state: AppState) {
///          // ...
///        }
///      }
///
///      init() {
///        self.viewStore = ViewStore(
///          self.store.scope(
///            state: SceneState.init(state:)
///            action: AppAction.scene
///          )
///        )
///      }
///
///      var body: some Scene {
///        WindowGroup {
///          MyRootView()
///        }
///        .commands {
///          CommandMenu("Help") {
///            Button("About \(self.viewStore.appName)") {
///              self.viewStore.send(.aboutButtonTapped)
///            }
///          }
///        }
///      }
///    }
///    ```
///
///    Note that it is highly discouraged for you to observe _all_ of your root store's state.
///    It is almost never needed and will cause many view recomputations leading to poor
///    performance. This is why we construct a separate `SceneState` type that holds onto only the
///    state that the view needs for rendering. See <doc:Performance> for more information on this
///    topic.
///
/// If your view does not need access to any state in the store and only needs to be able to send
/// actions, then you should consider not using ``WithViewStore`` at all. Instead, you can send
/// actions to a ``Store`` in a lightweight way like so:
///
/// ```swift
/// Button("Tap me") {
///   ViewStore(self.store).send(.buttonTapped)
/// }
/// ```
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
    #if DEBUG
      return self.content(self.store, self.prefix)
    #else
      return self.content(self.store, nil)
    #endif
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
    _ viewStore: @autoclosure @escaping () -> ViewStore<State, Action>,
    content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString,
    line: UInt,
    prefix: String? = nil
  ) {
    self._viewStore = .init(wrappedValue: viewStore())
    self.content = content
    #if DEBUG
      self.file = file
      self.line = line
      self.prefix = prefix
      var previousState: State? = nil
      self.previousState = { currentState in
        defer { previousState = currentState }
        return previousState
      }
    #endif
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
    _ viewStore: ViewStore<State, Action>,
    content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString,
    line: UInt,
    prefix: String? = nil
  ) {
    self.viewStore = viewStore
    self.content = content
    #if DEBUG
      self.file = file
      self.line = line
      self.prefix = prefix
      var previousState: State? = nil
      self.previousState = { currentState in
        defer { previousState = currentState }
        return previousState
      }
    #endif
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
  // TODO: move docs for this init under overloads for WithViewStore
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  )
  where
    Content == _ConditionalContent<
      AnyView, _ObservedObjectViewStore<State, Action, ObservedContent>
    >
  {
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
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  )
  where
    Content == _ConditionalContent<
      AnyView, _ObservedObjectViewStore<State, Action, ObservedContent>
    >
  {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

extension WithViewStore where State == Void, Content: View {
  // TODO: move docs for this init under overloads for WithViewStore
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  )
  where
    Content == _ConditionalContent<
      AnyView, _ObservedObjectViewStore<State, Action, ObservedContent>
    >
  {
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
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore(),
      content: content,
      file: file,
      line: line,
      prefix: prefix
    )
  }
}

extension _ObservedObjectViewStore: View where Content: View {
  init(
    viewStore: ViewStore<State, Action>,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore,
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
  @available(
    *,
    deprecated,
    message:
      """
     For compiler performance, using "WithViewStore" from an accessibility rotor content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

     See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
     """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) ->
      ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
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
  @available(
    *,
    deprecated,
    message:
      """
     For compiler performance, using "WithViewStore" from an accessibility rotor content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

     See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
     """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) ->
      ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
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
  @available(
    *,
    deprecated,
    message:
      """
     For compiler performance, using "WithViewStore" from an accessibility rotor content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

     See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
     """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) ->
      ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension _StateObjectViewStore: AccessibilityRotorContent
where Content: AccessibilityRotorContent {
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore(),
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
  @available(
    *,
    deprecated,
    message:
      """
       For compiler performance, using "WithViewStore" from a command builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

       See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
       """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
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
  @available(
    *,
    deprecated,
    message:
      """
       For compiler performance, using "WithViewStore" from a command builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

       See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
       """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
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
  @available(
    *,
    deprecated,
    message:
      """
       For compiler performance, using "WithViewStore" from a command builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

       See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
       """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension _StateObjectViewStore: Commands where Content: Commands {
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore(),
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
  @available(
    *,
    deprecated,
    message:
      """
       For compiler performance, using "WithViewStore" from a scene builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

       See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
       """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
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
  @available(
    *,
    deprecated,
    message:
      """
       For compiler performance, using "WithViewStore" from a scene builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

       See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
       """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
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
  @available(
    *,
    deprecated,
    message:
      """
       For compiler performance, using "WithViewStore" from a scene builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

       See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
       """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension _StateObjectViewStore: Scene where Content: Scene {
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore(),
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
  @available(
    *,
    deprecated,
    message:
      """
       For compiler performance, using "WithViewStore" from a toolbar content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

       See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
       """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
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
  @available(
    *,
    deprecated,
    message:
      """
       For compiler performance, using "WithViewStore" from a toolbar content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

       See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
       """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
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
  @available(
    *,
    deprecated,
    message:
      """
       For compiler performance, using "WithViewStore" from a toolbar content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.

       See the documentation for "WithViewStore" (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/viewstore#overview) for more information.
       """
  )
  public init<ObservedContent>(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> ObservedContent
  ) where Content == _StateObjectViewStore<State, Action, ObservedContent> {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension _StateObjectViewStore: ToolbarContent where Content: ToolbarContent {
  fileprivate init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line,
    prefix: String?
  ) {
    self.init(
      viewStore(),
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
