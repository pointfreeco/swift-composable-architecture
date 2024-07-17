import CustomDump
import SwiftUI

/// A view helper that transforms a ``Store`` into a ``ViewStore`` so that its state can be observed
/// by a view builder.
///
/// This helper is an alternative to observing the view store manually on your view, which requires
/// the boilerplate of a custom initializer.
///
/// > Important: It is important to properly leverage the `observe` argument in order to observe
/// only the state that your view needs to do its job. See the "Performance" section below for more
/// information.
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
/// actions directly to a ``Store`` like so:
///
/// ```swift
/// Button("Tap me") {
///   self.store.send(.buttonTapped)
/// }
/// ```
///
/// ## Performance
///
/// A common performance pitfall when using the library comes from constructing ``ViewStore``s and
/// ``WithViewStore``s. When constructed naively, using either view store's initializer
/// ``ViewStore/init(_:observe:)-3ak1y`` or the SwiftUI helper ``WithViewStore``, it  will observe
/// every change to state in the store:
///
/// ```swift
/// WithViewStore(self.store, observe: { $0 }) { viewStore in
///   // This is executed for every action sent into the system
///   // that causes self.store.state to change.
/// }
/// ```
///
/// Most of the time this observes far too much state. A typical feature in the Composable
/// Architecture holds onto not only the state the view needs to present UI, but also state that the
/// feature only needs internally, as well as state of child features embedded in the feature.
/// Changes to the internal and child state should not cause the view's body to re-compute since
/// that state is not needed in the view.
///
/// For example, if the root of our application was a tab view, then we could model that in state
/// as a struct that holds each tab's state as a property:
///
/// ```swift
/// @Reducer
/// struct AppFeature {
///   struct State {
///     var activity: Activity.State
///     var search: Search.State
///     var profile: Profile.State
///   }
///   // ...
/// }
/// ```
///
/// If the view only needs to construct the views for each tab, then no view store is even needed
/// because we can pass scoped stores to each child feature view:
///
/// ```swift
/// struct AppView: View {
///   let store: StoreOf<AppFeature>
///
///   var body: some View {
///     // No need to observe state changes because the view does
///     // not need access to the state.
///     TabView {
///       ActivityView(
///         store: self.store
///           .scope(state: \.activity, action: \.activity)
///       )
///       SearchView(
///         store: self.store
///           .scope(state: \.search, action: \.search)
///       )
///       ProfileView(
///         store: self.store
///           .scope(state: \.profile, action: \.profile)
///       )
///     }
///   }
/// }
/// ```
///
/// This means `AppView` does not actually need to observe any state changes. This view will only be
/// created a single time, whereas if we observed the store then it would re-compute every time a single
/// thing changed in either the activity, search or profile child features.
///
/// If sometime in the future we do actually need some state from the store, we can start to observe
/// only the bare essentials of state necessary for the view to do its job. For example, suppose that
/// we need access to the currently selected tab in state:
///
/// ```swift
/// @Reducer
/// struct AppFeature {
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
/// Then we can observe this state so that we can construct a binding to `selectedTab` for the tab view:
///
/// ```swift
/// struct AppView: View {
///   let store: StoreOf<AppFeature>
///
///   var body: some View {
///     WithViewStore(self.store, observe: { $0 }) { viewStore in
///       TabView(
///         selection: viewStore.binding(get: \.selectedTab, send: { .tabSelected($0) })
///       ) {
///         ActivityView(
///           store: self.store.scope(state: \.activity, action: \.activity)
///         )
///         .tag(AppFeature.Tab.activity)
///         SearchView(
///           store: self.store.scope(state: \.search, action: \.search)
///         )
///         .tag(AppFeature.Tab.search)
///         ProfileView(
///           store: self.store.scope(state: \.profile, action: \.profile)
///         )
///         .tag(AppFeature.Tab.profile)
///       }
///     }
///   }
/// }
/// ```
///
/// However, this style of state observation is terribly inefficient since _every_ change to
/// `AppFeature.State` will cause the view to re-compute even though the only piece of state we
/// actually care about is the `selectedTab`. The reason we are observing too much state is because
/// we use `observe: { $0 }` in the construction of the ``WithViewStore``, which means the view
/// store will observe all of state.
///
/// To chisel away at the observed state you can provide a closure for that argument that plucks out
/// the state the view needs. In this case the view only needs a single field:
///
/// ```swift
/// WithViewStore(self.store, observe: \.selectedTab) { viewStore in
///   TabView(selection: viewStore.binding(send: { .tabSelected($0) }) {
///     // ...
///   }
/// }
/// ```
///
/// In the future, the view may need access to more state. For example, suppose `Activity.State`
/// holds onto an `unreadCount` integer to represent how many new activities you have. There's no
/// need to observe _all_ of `Activity.State` to get access to this one field. You can observe just
/// the one field.
///
/// Technically you can do this by mapping your state into a tuple, but because tuples are not
/// `Equatable` you will need to provide an explicit `removeDuplicates` argument:
///
/// ```swift
/// WithViewStore(
///   self.store,
///   observe: { (selectedTab: $0.selectedTab, unreadActivityCount: $0.activity.unreadCount) },
///   removeDuplicates: ==
/// ) { viewStore in
///   TabView(selection: viewStore.binding(get: \.selectedTab, send: { .tabSelected($0) }) {
///     ActivityView(
///       store: self.store.scope(state: \.activity, action: \.activity)
///     )
///     .tag(AppFeature.Tab.activity)
///     .badge("\(viewStore.unreadActivityCount)")
///
///     // ...
///   }
/// }
/// ```
///
/// Alternatively, and recommended, you can introduce a lightweight, equatable `ViewState` struct
/// nested inside your view whose purpose is to transform the `Store`'s full state into the bare
/// essentials of what the view needs:
///
/// ```swift
/// struct AppView: View {
///   let store: StoreOf<AppFeature>
///
///   struct ViewState: Equatable {
///     let selectedTab: AppFeature.Tab
///     let unreadActivityCount: Int
///     init(state: AppFeature.State) {
///       self.selectedTab = state.selectedTab
///       self.unreadActivityCount = state.activity.unreadCount
///     }
///   }
///
///   var body: some View {
///     WithViewStore(self.store, observe: ViewState.init) { viewStore in
///       TabView {
///         ActivityView(
///           store: self.store
///             .scope(state: \.activity, action: \.activity)
///         )
///         .badge("\(viewStore.unreadActivityCount)")
///
///         // ...
///       }
///     }
///   }
/// }
/// ```
///
/// This gives you maximum flexibility in the future for adding new fields to `ViewState` without
/// making your view convoluted.
///
/// This technique for reducing view re-computations is most effective towards the root of your app
/// hierarchy and least effective towards the leaf nodes of your app. Root features tend to hold
/// lots of state that its view does not need, such as child features, and leaf features tend to
/// only hold what's necessary. If you are going to employ this technique you will get the most
/// benefit by applying it to views closer to the root. At leaf features and views that need access
/// to most of the state, it is fine to continue using `observe: { $0 }` to observe all of the state
/// in the store.
@available(
  iOS,
  deprecated: 9999,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
@available(
  macOS,
  deprecated: 9999,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
@available(
  tvOS,
  deprecated: 9999,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
@available(
  watchOS,
  deprecated: 9999,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
public struct WithViewStore<ViewState, ViewAction, Content: View>: View {
  private let content: (ViewStore<ViewState, ViewAction>) -> Content
  #if DEBUG
    private let file: StaticString
    private let line: UInt
    private var prefix: String?
    private var previousState: (ViewState) -> ViewState?
    private var storeTypeName: String
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
      self.storeTypeName = ComposableArchitecture.storeTypeName(of: store)
    #endif
    self.viewStore = ViewStore(store, observe: { $0 }, removeDuplicates: isDuplicate)
  }

  /// Prints debug information to the console whenever the view is computed.
  ///
  /// - Parameter prefix: A string with which to prefix all debug messages.
  /// - Returns: A structure that prints debug messages for all computations.
  @_documentation(visibility:public)
  public func _printChanges(_ prefix: String = "") -> Self {
    var view = self
    #if DEBUG
      view.prefix = prefix
    #endif
    return view
  }

  public var body: Content {
    #if DEBUG
      Logger.shared.log("WithView\(storeTypeName).body")
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
  /// @Reducer
  /// struct AppFeature {
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
  ///       TabView(selection: viewStore.binding(send: { .tabSelected($0) }) {
  ///         ActivityView(
  ///           store: self.store.scope(state: \.activity, action: \.activity)
  ///         )
  ///         .tag(AppFeature.Tab.activity)
  ///         SearchView(
  ///           store: self.store.scope(state: \.search, action: \.search)
  ///         )
  ///         .tag(AppFeature.Tab.search)
  ///         ProfileView(
  ///           store: self.store.scope(state: \.profile, action: \.profile)
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
  ///     are equal, repeat view computations are removed.
  ///   - content: A function that can generate content from a view store.
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(
        id: nil,
        state: ToState(toViewState),
        action: fromViewAction,
        isInvalid: nil
      ),
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
  /// @Reducer
  /// struct AppFeature {
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
  ///       TabView(selection: viewStore.binding(send: { .tabSelected($0) }) {
  ///         ActivityView(
  ///           store: self.store.scope(state: \.activity, action: \.activity)
  ///         )
  ///         .tag(AppFeature.Tab.activity)
  ///         SearchView(
  ///           store: self.store.scope(state: \.search, action: \.search)
  ///         )
  ///         .tag(AppFeature.Tab.search)
  ///         ProfileView(
  ///           store: self.store.scope(state: \.profile, action: \.profile)
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
  ///     are equal, repeat view computations are removed.
  ///   - content: A function that can generate content from a view store.
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(
        id: nil,
        state: ToState(toViewState),
        action: { $0 },
        isInvalid: nil
      ),
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
  /// @Reducer
  /// struct AppFeature {
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
  ///       TabView(selection: viewStore.binding(send: { .tabSelected($0) }) {
  ///         ActivityView(
  ///           store: self.store.scope(state: \.activity, action: \.activity)
  ///         )
  ///         .tag(AppFeature.Tab.activity)
  ///         SearchView(
  ///           store: self.store.scope(state: \.search, action: \.search)
  ///         )
  ///         .tag(AppFeature.Tab.search)
  ///         ProfileView(
  ///           store: self.store.scope(state: \.profile, action: \.profile)
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
  ///   - content: A function that can generate content from a view store.
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(
        id: nil,
        state: ToState(toViewState),
        action: fromViewAction,
        isInvalid: nil
      ),
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
  /// @Reducer
  /// struct AppFeature {
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
  ///       TabView(selection: viewStore.binding(send: { .tabSelected($0) }) {
  ///         ActivityView(
  ///           store: self.store.scope(state: \.activity, action: \.activity)
  ///         )
  ///         .tag(AppFeature.Tab.activity)
  ///         SearchView(
  ///           store: self.store.scope(state: \.search, action: \.search)
  ///         )
  ///         .tag(AppFeature.Tab.search)
  ///         ProfileView(
  ///           store: self.store.scope(state: \.profile, action: \.profile)
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
  ///   - content: A function that can generate content from a view store.
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(
        id: nil,
        state: ToState(toViewState),
        action: { $0 },
        isInvalid: nil
      ),
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
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
