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
///   let store: StoreOf<Profile>
///   @ObservedObject var viewStore: ViewStoreOf<Profile>
///
///   init(store: StoreOf<Profile>) {
///     self.store = store
///     self.viewStore = ViewStore(store, observe: { $0 })
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
///   let store: StoreOf<Profile>
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
///   1. When ``WithViewStore`` wraps complex views the Swift compiler can quickly become bogged
///      down, leading to degraded compiler performance and diagnostics. If you are experiencing
///      such instability you should consider manually setting up observation with an
///      `@ObservedObject` property as described above.
///
///   2. Sometimes you may want to observe the state in a store in a context that is not a view
///      builder. In such cases ``WithViewStore`` will not work since it is intended only for
///      SwiftUI views.
///
///      An example of this is interfacing with SwiftUI's `App` protocol, which uses a separate
///      `@SceneBuilder` instead of `@ViewBuilder`. In this case you must use an `@ObservedObject`:
///
///      ```swift
///      @main
///      struct MyApp: App {
///        let store = StoreOf<AppFeature>(/* ... */)
///        @ObservedObject var viewStore: ViewStore<SceneState, CommandAction>
///
///        struct SceneState: Equatable {
///          // ...
///          init(state: AppFeature.State) {
///            // ...
///          }
///        }
///
///        init() {
///          self.viewStore = ViewStore(
///            self.store.scope(
///              state: SceneState.init(state:)
///              action: AppFeature.Action.scene
///            )
///          )
///        }
///
///        var body: some Scene {
///          WindowGroup {
///            MyRootView()
///          }
///          .commands {
///            CommandMenu("Help") {
///              Button("About \(self.viewStore.appName)") {
///                self.viewStore.send(.aboutButtonTapped)
///              }
///            }
///          }
///        }
///      }
///      ```
///
///      Note that it is highly discouraged for you to observe _all_ of your root store's state.
///      It is almost never needed and will cause many view recomputations leading to poor
///      performance. This is why we construct a separate `SceneState` type that holds onto only the
///      state that the view needs for rendering. See <doc:Performance> for more information on this
///      topic.
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
public struct WithViewStore<ViewState, ViewAction, Content: View>: View {
  private let content: (ViewStore<ViewState, ViewAction>) -> Content
  #if DEBUG
    private let file: StaticString
    private let line: UInt
    private var prefix: String?
    private var previousState: (ViewState) -> ViewState?
  #endif
  @ObservedObject private var viewStore: ViewStore<ViewState, ViewAction>

  init(
    store: Store<ViewState, ViewAction>,
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
    self.viewStore = ViewStore(store, removeDuplicates: isDuplicate)
  }

  /// Prints debug information to the console whenever the view is computed.
  ///
  /// - Parameter prefix: A string with which to prefix all debug messages.
  /// - Returns: A structure that prints debug messages for all computations.
  public func _printChanges(_ prefix: String = "") -> Self {
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

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute views from state.
  ///
  /// ``WithViewStore`` will re-compute its body for _any_ change to the state it holds. Often the
  /// ``Store`` that we want to observe holds onto a lot more state than is necessary to render a
  /// view. It may hold onto the state of child features, or internal state for its logic.
  ///
  /// It can be important to transform the ``Store``'s state into something smaller for observation.
  /// This will help minimize the number of times your view re-computes its body, and can even avoid
  /// certain SwiftUI bugs that happen due to over-rendering.
  ///
  /// The way to do this is to use the `observe` argument of this initializer. It allows you to
  /// turn the full state into a smaller data type, and only changes to that data type will trigger
  /// a body re-computation.
  ///
  /// For example, if your application uses a tab view, then the root state may hold the state
  /// for each tab as well as the currently selected tab:
  ///
  /// ```swift
  /// struct AppFeature: ReducerProtocol {
  ///   enum Tab { case activity, search, profile }
  ///   struct State {
  ///     var activity: Activity.State
  ///     var search: Search.State
  ///     var profile: Profile.State
  ///     var selectedTab: Tab
  ///   }
  ///   // ...
  /// }
  /// ```
  ///
  /// In order to construct a tab view you need to observe this state because changes to
  /// `selectedTab` need to make SwiftUI update the visual state of the UI. However, you do not
  /// need to observe changes to `activity`, `search` and `profile`. Those are only necessary for
  /// those child features, and changes to that state should not cause our tab view to re-compute
  /// itself.
  ///
  /// ```swift
  /// struct AppView: View {
  ///   let store: StoreOf<AppFeature>
  ///
  ///   var body: some View {
  ///     WithViewStore(self.store, observe: \.selectedTab) { viewStore in
  ///       TabView(selection: viewStore.binding(send: AppFeature.Action.tabSelected) {
  ///         ActivityView(
  ///           store: self.store.scope(state: \.activity, action: AppFeature.Action.activity)
  ///         )
  ///         .tag(AppFeature.Tab.activity)
  ///         SearchView(
  ///           store: self.store.scope(state: \.search, action: AppFeature.Action.search)
  ///         )
  ///         .tag(AppFeature.Tab.search)
  ///         ProfileView(
  ///           store: self.store.scope(state: \.profile, action: AppFeature.Action.profile)
  ///         )
  ///         .tag(AppFeature.Tab.profile)
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// To read more about this performance technique, read the <doc:Performance> article.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms store state into observable view state. All
  ///   changes to the view state will cause the `WithViewStore` to re-compute its view.
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

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute views from state.
  ///
  /// ``WithViewStore`` will re-compute its body for _any_ change to the state it holds. Often the
  /// ``Store`` that we want to observe holds onto a lot more state than is necessary to render a
  /// view. It may hold onto the state of child features, or internal state for its logic.
  ///
  /// It can be important to transform the ``Store``'s state into something smaller for observation.
  /// This will help minimize the number of times your view re-computes its body, and can even avoid
  /// certain SwiftUI bugs that happen due to over-rendering.
  ///
  /// The way to do this is to use the `observe` argument of this initializer. It allows you to
  /// turn the full state into a smaller data type, and only changes to that data type will trigger
  /// a body re-computation.
  ///
  /// For example, if your application uses a tab view, then the root state may hold the state
  /// for each tab as well as the currently selected tab:
  ///
  /// ```swift
  /// struct AppFeature: ReducerProtocol {
  ///   enum Tab { case activity, search, profile }
  ///   struct State {
  ///     var activity: Activity.State
  ///     var search: Search.State
  ///     var profile: Profile.State
  ///     var selectedTab: Tab
  ///   }
  ///   // ...
  /// }
  /// ```
  ///
  /// In order to construct a tab view you need to observe this state because changes to
  /// `selectedTab` need to make SwiftUI update the visual state of the UI. However, you do not
  /// need to observe changes to `activity`, `search` and `profile`. Those are only necessary for
  /// those child features, and changes to that state should not cause our tab view to re-compute
  /// itself.
  ///
  /// ```swift
  /// struct AppView: View {
  ///   let store: StoreOf<AppFeature>
  ///
  ///   var body: some View {
  ///     WithViewStore(self.store, observe: \.selectedTab) { viewStore in
  ///       TabView(selection: viewStore.binding(send: AppFeature.Action.tabSelected) {
  ///         ActivityView(
  ///           store: self.store.scope(state: \.activity, action: AppFeature.Action.activity)
  ///         )
  ///         .tag(AppFeature.Tab.activity)
  ///         SearchView(
  ///           store: self.store.scope(state: \.search, action: AppFeature.Action.search)
  ///         )
  ///         .tag(AppFeature.Tab.search)
  ///         ProfileView(
  ///           store: self.store.scope(state: \.profile, action: AppFeature.Action.profile)
  ///         )
  ///         .tag(AppFeature.Tab.profile)
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// To read more about this performance technique, read the <doc:Performance> article.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms store state into observable view state. All
  ///   changes to the view state will cause the `WithViewStore` to re-compute its view.
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
      store: store.scope(state: toViewState, action: { $0 }),
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from store state.
  ///
  /// > Warning: This initializer is deprecated. Use
  /// ``WithViewStore/init(_:observe:removeDuplicates:content:file:line:)`` to make state
  /// observation explicit.
  /// >
  /// > When using ``WithViewStore`` you should take care to observe only the pieces of state that
  /// your view needs to do its job, especially towards the root of the application. See
  /// <doc:Performance> for more details.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  @available(
    iOS,
    deprecated: 9999,
    message:
      """
      Use 'init(_:observe:removeDuplicates:content:)' to make state observation explicit.

      When using WithViewStore you should take care to observe only the pieces of state that your view needs to do its job, especially towards the root of the application. See the performance article for more details:

      https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance#View-stores
      """
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      """
      Use 'init(_:observe:removeDuplicates:content:)' to make state observation explicit.

      When using WithViewStore you should take care to observe only the pieces of state that your view needs to do its job, especially towards the root of the application. See the performance article for more details:

      https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance#View-stores
      """
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      """
      Use 'init(_:observe:removeDuplicates:content:)' to make state observation explicit.

      When using WithViewStore you should take care to observe only the pieces of state that your view needs to do its job, especially towards the root of the application. See the performance article for more details:

      https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance#View-stores
      """
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      """
      Use 'init(_:observe:removeDuplicates:content:)' to make state observation explicit.

      When using WithViewStore you should take care to observe only the pieces of state that your view needs to do its job, especially towards the root of the application. See the performance article for more details:

      https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance#View-stores
      """
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
  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute views from state.
  ///
  /// ``WithViewStore`` will re-compute its body for _any_ change to the state it holds. Often the
  /// ``Store`` that we want to observe holds onto a lot more state than is necessary to render a
  /// view. It may hold onto the state of child features, or internal state for its logic.
  ///
  /// It can be important to transform the ``Store``'s state into something smaller for observation.
  /// This will help minimize the number of times your view re-computes its body, and can even avoid
  /// certain SwiftUI bugs that happen due to over-rendering.
  ///
  /// The way to do this is to use the `observe` argument of this initializer. It allows you to
  /// turn the full state into a smaller data type, and only changes to that data type will trigger
  /// a body re-computation.
  ///
  /// For example, if your application uses a tab view, then the root state may hold the state
  /// for each tab as well as the currently selected tab:
  ///
  /// ```swift
  /// struct AppFeature: ReducerProtocol {
  ///   enum Tab { case activity, search, profile }
  ///   struct State {
  ///     var activity: Activity.State
  ///     var search: Search.State
  ///     var profile: Profile.State
  ///     var selectedTab: Tab
  ///   }
  ///   // ...
  /// }
  /// ```
  ///
  /// In order to construct a tab view you need to observe this state because changes to
  /// `selectedTab` need to make SwiftUI update the visual state of the UI. However, you do not
  /// need to observe changes to `activity`, `search` and `profile`. Those are only necessary for
  /// those child features, and changes to that state should not cause our tab view to re-compute
  /// itself.
  ///
  /// ```swift
  /// struct AppView: View {
  ///   let store: StoreOf<AppFeature>
  ///
  ///   var body: some View {
  ///     WithViewStore(self.store, observe: \.selectedTab) { viewStore in
  ///       TabView(selection: viewStore.binding(send: AppFeature.Action.tabSelected) {
  ///         ActivityView(
  ///           store: self.store.scope(state: \.activity, action: AppFeature.Action.activity)
  ///         )
  ///         .tag(AppFeature.Tab.activity)
  ///         SearchView(
  ///           store: self.store.scope(state: \.search, action: AppFeature.Action.search)
  ///         )
  ///         .tag(AppFeature.Tab.search)
  ///         ProfileView(
  ///           store: self.store.scope(state: \.profile, action: AppFeature.Action.profile)
  ///         )
  ///         .tag(AppFeature.Tab.profile)
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// To read more about this performance technique, read the <doc:Performance> article.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms store state into observable view state. All
  ///   changes to the view state will cause the `WithViewStore` to re-compute its view.
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

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute views from state.
  ///
  /// ``WithViewStore`` will re-compute its body for _any_ change to the state it holds. Often the
  /// ``Store`` that we want to observe holds onto a lot more state than is necessary to render a
  /// view. It may hold onto the state of child features, or internal state for its logic.
  ///
  /// It can be important to transform the ``Store``'s state into something smaller for observation.
  /// This will help minimize the number of times your view re-computes its body, and can even avoid
  /// certain SwiftUI bugs that happen due to over-rendering.
  ///
  /// The way to do this is to use the `observe` argument of this initializer. It allows you to
  /// turn the full state into a smaller data type, and only changes to that data type will trigger
  /// a body re-computation.
  ///
  /// For example, if your application uses a tab view, then the root state may hold the state
  /// for each tab as well as the currently selected tab:
  ///
  /// ```swift
  /// struct AppFeature: ReducerProtocol {
  ///   enum Tab { case activity, search, profile }
  ///   struct State {
  ///     var activity: Activity.State
  ///     var search: Search.State
  ///     var profile: Profile.State
  ///     var selectedTab: Tab
  ///   }
  ///   // ...
  /// }
  /// ```
  ///
  /// In order to construct a tab view you need to observe this state because changes to
  /// `selectedTab` need to make SwiftUI update the visual state of the UI. However, you do not
  /// need to observe changes to `activity`, `search` and `profile`. Those are only necessary for
  /// those child features, and changes to that state should not cause our tab view to re-compute
  /// itself.
  ///
  /// ```swift
  /// struct AppView: View {
  ///   let store: StoreOf<AppFeature>
  ///
  ///   var body: some View {
  ///     WithViewStore(self.store, observe: \.selectedTab) { viewStore in
  ///       TabView(selection: viewStore.binding(send: AppFeature.Action.tabSelected) {
  ///         ActivityView(
  ///           store: self.store.scope(state: \.activity, action: AppFeature.Action.activity)
  ///         )
  ///         .tag(AppFeature.Tab.activity)
  ///         SearchView(
  ///           store: self.store.scope(state: \.search, action: AppFeature.Action.search)
  ///         )
  ///         .tag(AppFeature.Tab.search)
  ///         ProfileView(
  ///           store: self.store.scope(state: \.profile, action: AppFeature.Action.profile)
  ///         )
  ///         .tag(AppFeature.Tab.profile)
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// To read more about this performance technique, read the <doc:Performance> article.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms store state into observable view state. All
  ///   changes to the view state will cause the `WithViewStore` to re-compute its view.
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
      store: store.scope(state: toViewState, action: { $0 }),
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable store state.
  ///
  /// > Warning: This initializer is deprecated. Use
  /// ``WithViewStore/init(_:observe:content:file:line:)`` to make state
  /// observation explicit.
  /// >
  /// > When using ``WithViewStore`` you should take care to observe only the pieces of state that
  /// your view needs to do its job, especially towards the root of the application. See
  /// <doc:Performance> for more details.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  @available(
    iOS,
    deprecated: 9999,
    message:
      """
      Use 'init(_:observe:content:)' to make state observation explicit.

      When using WithViewStore you should take care to observe only the pieces of state that your view needs to do its job, especially towards the root of the application. See the performance article for more details:

      https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance#View-stores
      """
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      """
      Use 'init(_:observe:content:)' to make state observation explicit.

      When using WithViewStore you should take care to observe only the pieces of state that your view needs to do its job, especially towards the root of the application. See the performance article for more details:

      https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance#View-stores
      """
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      """
      Use 'init(_:observe:content:)' to make state observation explicit.

      When using WithViewStore you should take care to observe only the pieces of state that your view needs to do its job, especially towards the root of the application. See the performance article for more details:

      https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance#View-stores
      """
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      """
      Use 'init(_:observe:content:)' to make state observation explicit.

      When using WithViewStore you should take care to observe only the pieces of state that your view needs to do its job, especially towards the root of the application. See the performance article for more details:

      https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance#View-stores
      """
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
