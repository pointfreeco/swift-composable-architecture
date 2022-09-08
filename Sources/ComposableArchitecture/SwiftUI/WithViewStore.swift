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
///     WithViewStore(self.store, observe: { $0 }) { viewStore in
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
public struct WithViewStore<ViewState, ViewAction, Content> {
  private let content: (ViewStore<ViewState, ViewAction>) -> Content
  #if DEBUG
    private let file: StaticString
    private let line: UInt
    private var prefix: String?
    private var previousState: (ViewState) -> ViewState?
  #endif
  @_StateObject private var viewStore: ViewStore<ViewState, ViewAction>

  init(
    store: @autoclosure @escaping () -> Store<ViewState, ViewAction>,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.content = content
    #if DEBUG
      self.file = file
      self.line = line
      var previousState: ViewState? = nil
      self.previousState = { currentState in
        defer { previousState = currentState }
        return previousState
      }
    #endif
    self._viewStore = .init(wrappedValue: ViewStore(store(), removeDuplicates: isDuplicate))
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
      if let prefix = self.prefix {
        var stateDump = ""
        customDump(self.viewStore.state, to: &stateDump, indent: 2)
        let difference =
          self.previousState(self.viewStore.state)
          .map {
            diff($0, self.viewStore.state).map { "(Changed state)\n\($0)" }
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
          WithViewStore<\(typeName(ViewState.self)), \(typeName(ViewAction.self)), _>\
          @\(self.file):\(self.line) \(difference)
          """
        )
      }
    #endif
    return self.content(ViewStore(self.viewStore))
  }
}

// MARK: - View

extension WithViewStore: View where Content: View {
  // TODO: move docs for this init under overloads for WithViewStore
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms store state into observable view state.
  ///   - fromViewAction: A function that transforms view actions into store action.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (State) -> ViewState,
    send fromViewAction: @escaping (ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    @ViewBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(state: toViewState, action: fromViewAction),
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms store state into observable view state.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (State) -> ViewState,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    @ViewBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(state: toViewState),
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from store state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  @available(
    iOS,
    deprecated: 9999.0,
    message: "Use 'init(_:observe:removeDuplicates:content:)' to make state observation explicit."
  )
  @available(
    macOS,
    deprecated: 9999.0,
    message: "Use 'init(_:observe:removeDuplicates:content:)' to make state observation explicit."
  )
  @available(
    tvOS,
    deprecated: 9999.0,
    message: "Use 'init(_:observe:removeDuplicates:content:)' to make state observation explicit."
  )
  @available(
    watchOS,
    deprecated: 9999.0,
    message: "Use 'init(_:observe:removeDuplicates:content:)' to make state observation explicit."
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    @ViewBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store,
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

extension WithViewStore where ViewState: Equatable, Content: View {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms store state into observable view state.
  ///   - fromViewAction: A function that transforms view actions into store action.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (State) -> ViewState,
    send fromViewAction: @escaping (ViewAction) -> Action,
    @ViewBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(state: toViewState, action: fromViewAction),
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable state.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms store state into observable view state.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (State) -> ViewState,
    @ViewBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(state: toViewState),
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    iOS,
    deprecated: 9999.0,
    message: "Use 'init(_:observe:content:)' to make state observation explicit."
  )
  @available(
    macOS,
    deprecated: 9999.0,
    message: "Use 'init(_:observe:content:)' to make state observation explicit."
  )
  @available(
    tvOS,
    deprecated: 9999.0,
    message: "Use 'init(_:observe:content:)' to make state observation explicit."
  )
  @available(
    watchOS,
    deprecated: 9999.0,
    message: "Use 'init(_:observe:content:)' to make state observation explicit."
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    @ViewBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(store, removeDuplicates: ==, content: content, file: file, line: line)
  }
}

extension WithViewStore where ViewState == Void, Content: View {
  // TODO: move docs for this init under overloads for WithViewStore

  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    iOS,
    deprecated: 9999.0,
    message: "Use 'ViewStore(store).send(action)' instead of observing stateless stores."
  )
  @available(
    macOS,
    deprecated: 9999.0,
    message: "Use 'ViewStore(store).send(action)' instead of observing stateless stores."
  )
  @available(
    tvOS,
    deprecated: 9999.0,
    message: "Use 'ViewStore(store).send(action)' instead of observing stateless stores."
  )
  @available(
    watchOS,
    deprecated: 9999.0,
    message: "Use 'ViewStore(store).send(action)' instead of observing stateless stores."
  )
  public init(
    _ store: Store<ViewState, ViewAction>,
    @ViewBuilder content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(store, removeDuplicates: ==, content: content, file: file, line: line)
  }
}

extension WithViewStore: DynamicViewContent
where
  ViewState: Collection,
  Content: DynamicViewContent
{
  public typealias Data = ViewState

  public var data: ViewState {
    self.viewStore.state
  }
}
