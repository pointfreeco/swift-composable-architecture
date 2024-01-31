#if swift(>=5.9)
  import Observation

  /// Helps implement the conformance to the ``Reducer`` protocol for a type.
  ///
  /// To use this macro you will define a new type, typically a struct, and add inner types for the
  /// ``Reducer/State`` and ``Reducer/Action`` associated types, as well as an implementation of the
  /// reducer's ``Reducer/body-8lumc``:
  ///
  /// ```swift
  /// @Reducer
  /// struct Feature {
  ///   struct State {
  ///     var count = 0
  ///   }
  ///   enum Action {
  ///     case decrementButtonTapped
  ///     case incrementButtonTapped
  ///   }
  ///   var body: some ReducerOf<Self> {
  ///     Reduce { state, action in
  ///       switch action {
  ///       case .decrementButtonTapped:
  ///         state.count -= 1
  ///         return .none
  ///       case .incrementButtonTapped:
  ///         state.count += 1
  ///         return .none
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// This will expand Swift code to conform `Feature` to the ``Reducer`` protocol:
  ///
  /// ```diff
  /// +extension Feature: Reducer {}
  /// ```
  ///
  /// It will also apply the `@CasePathable` macro to the `enum Action`:
  ///
  /// ```diff
  /// +@CasePathable
  ///  enum Action {
  ///    // ...
  ///  }
  /// ```
  ///
  /// This will allow you to use key path syntax for specifying enum cases in various APIs in the
  /// library, such as ``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at``,
  /// ``Reducer/forEach(_:action:destination:fileID:line:)-yz3v``, ``Scope``, and more.
  ///
  /// Further, if the ``Reducer/State`` of your feature is an enum, which is useful for modeling a
  /// feature that can be one of multiple mutually exclusive values, the ``Reducer()`` will apply
  /// the `@CasePathable` macro, as well as `@dynamicMemberLookup`:
  ///
  /// ```diff
  /// +@CasePathable
  /// +@dynamicMemberLookup
  ///  enum State {
  ///    // ...
  ///  }
  /// ```
  ///
  /// This will allow you to use key path syntax for specifying case paths to the `State`'s cases,
  /// as well as allow you to use dot-chaining syntax for optionally extracting a case from the
  /// state. This can be useful when using the operators that come with the library that allow for
  /// driving navigation from an enum of options:
  ///
  /// ```swift
  /// .sheet(
  ///   item: $store.scope(state: \.destination?.editForm, action: \.destination.editForm)
  /// )
  /// ```
  ///
  /// The syntax `state: \.destination?.editForm` is only possible due to both
  /// `@dynamicMemberLookup` and `@CasePathable` being applied to the `State` enum.
  ///
  /// ## Automatic fulfillment of reducer requirements
  ///
  /// The ``Reducer()`` macro can automatically fill in the ``Reducer`` protocol's requirements for
  /// you. For example, something as simple as this:
  ///
  /// ```swift
  /// @Reducer
  /// struct Feature {
  /// }
  /// ```
  ///
  /// …compiles.
  ///
  /// The `@Reducer` macro will automatically insert an empty ``Reducer/State`` struct, an empty
  /// ``Reducer/Action`` enum, and an empty ``Reducer/body-swift.property``. This effectively means
  /// that `Feature` is a logicless, behaviorless, inert reducer.
  ///
  /// Having these requirements automatically fulfilled for you can be handy for slowly
  /// filling them in with their real implementations. For example, this `Feature` reducer could be
  /// integrated in a parent domain using the library's navigation tools, all without having
  /// implemented any of the domain yet. Then, once we are ready we can start implementing the real
  /// logic and behavior of the feature.
  ///
  /// ## Destination and path reducers
  ///
  /// There is a common pattern in the Composable Architecture of representing destinations a 
  /// feature can navigate to as a reducer that operates on enum state, with a case for each
  /// feature that can be navigated to. This is explained in great detail in the
  /// <doc:TreeBasedNavigation> and <doc:StackBasedNavigation> articles.
  ///
  /// This form of domain modeling can be very powerful, but also incur a bit of boilerplate. For 
  /// example, if a feature can navigate to 3 other features, then one might have a `Destination`
  /// reducer like the following:
  ///
  /// ```swift
  /// @Reducer
  /// struct Destination {
  ///   @ObservableState
  ///   enum State {
  ///     case add(FormFeature.State)
  ///     case detail(DetailFeature.State)
  ///     case edit(EditFeature.State)
  ///   }
  ///   enum Action {
  ///     case add(FormFeature.Action)
  ///     case detail(DetailFeature.Action)
  ///     case edit(EditFeature.Action)
  ///   }
  ///   var body: some ReducerOf<Self> {
  ///     Scope(state: \.add, action: \.add) {
  ///       FormFeature()
  ///     }
  ///     Scope(state: \.detail, action: \.detail) {
  ///       DetailFeature()
  ///     }
  ///     Scope(state: \.edit, action: \.edit) {
  ///       EditFeature()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// It's not the worst code in the world, but it is 24 lines with a lot of repetition, and if we 
  /// need to add a new destination we must add a case to the ``Reducer/State`` enum, a case to the
  /// ``Reducer/Action`` enum, and a ``Scope`` to the ``Reducer/body-swift.property``.
  ///
  /// The ``Reducer()`` macro is now capable of generating all of this code for you from the
  /// following simple declaration
  ///
  /// ```swift
  /// @Reducer
  /// enum Destination {
  ///   case add(FormFeature)
  ///   case detail(DetailFeature)
  ///   case edit(EditFeature)
  /// }
  /// ```
  ///
  /// 24 lines of code has become 6. The `@Reducer` macro can now be applied to an _enum_ where each
  /// case holds onto the reducer that governs the logic and behavior for that case. Further, when
  /// using the ``Reducer/ifLet(_:action:)`` operator with this style of `Destination` enum reducer
  /// you can completely leave off the trailing closure as it can be automatically inferred:
  ///
  /// ```swift
  /// Reduce { state, action in
  ///   // Core feature logic
  /// }
  /// .ifLet(\.$destination, action: \.destination)
  /// ```
  ///
  /// This pattern also works for `Path` reducers, which is common when dealing with
  /// <doc:StackBasedNavigation>, and in that case you can leave off the trailing closure of the
  /// ``Reducer/forEach(_:action:)`` operator:
  ///
  /// ```swift
  /// Reduce { state, action in
  ///   // Core feature logic
  /// }
  /// .forEach(\.path, action: \.path)
  /// ```
  ///
  /// ## Synthesizing protocol conformances on State and Action
  ///
  /// Since the `State` and `Action` types are generated automatically for you when using `@Reducer`
  /// on an enum, it's not possible to directly synthesize conformances of `Equatable`, `Hashable`,
  /// etc. on those types. And further, due to a bug in the Swift compiler you cannot currently
  /// do this:
  ///
  /// ```swift
  /// @Reducer
  /// enum Destination {
  ///   // ...
  /// }
  /// extension Destination.State: Equatable {}  // ❌
  /// ```
  ///
  /// See <doc:Reducer()#Circular-reference-errors> below for more info on this error.
  ///
  /// So, to work around this compiler bug the `@Reducer` macro takes two
  /// ``ComposableArchitecture/_SynthesizedConformance`` arguments that allow you to describe which
  /// protocols you want to attach to the `State` or `Action` types:
  ///
  /// ```swift
  /// @Reducer(state: .equatable, .sendable, action: .sendable)
  /// enum Destination {
  ///   // ...
  /// }
  /// ```
  ///
  /// You can provide any combination of
/// ``ComposableArchitecture/_SynthesizedConformance/codable``,
/// ``ComposableArchitecture/_SynthesizedConformance/decodable``,
/// ``ComposableArchitecture/_SynthesizedConformance/encodable``,
/// ``ComposableArchitecture/_SynthesizedConformance/equatable``,
/// ``ComposableArchitecture/_SynthesizedConformance/hashable``, or
/// ``ComposableArchitecture/_SynthesizedConformance/sendable``.
  ///
  /// ## Gotchas
  ///
  /// ### Autocomplete
  ///
  /// Applying `@Reducer` can break autocompletion in the `body` of the reducer. This is a known
  /// [issue](https://github.com/apple/swift/issues/69477), and it can generally be worked around by
  /// providing additional type hints to the compiler:
  ///
  ///  1. Adding an explicit `Reducer` conformance in addition to the macro application can restore
  ///     autocomplete throughout the `body` of the reducer:
  ///
  ///     ```diff
  ///      @Reducer
  ///     -struct Feature {
  ///     +struct Feature: Reducer {
  ///     ```
  ///
  ///  2. Adding explicit generics to instances of `Reduce` in the `body` can restore autocomplete
  ///     inside the `Reduce`:
  ///
  ///     ```diff
  ///      var body: some Reducer<State, Action> {
  ///     -  Reduce { state, action in
  ///     +  Reduce<State, Action> { state, action in
  ///     ```
  ///
  /// ### Circular reference errors
  ///
  /// There is currently a bug in the Swift compiler and macros that prevents you from extending
  /// types that are inside other types with macros applied in the same file. For example, if you
  /// wanted to extend a reducer's `State` with some extra functionality:
  ///
  /// ```swift
  /// @Reducer
  /// struct Feature {
  ///   struct State { /* ... */ }
  ///   // ...
  /// }
  ///
  /// extension Feature.State {  // 🛑 Circular reference
  ///   // ...
  /// }
  /// ```
  ///
  /// This unfortunately does not work. It is a
  /// [known issue](https://github.com/apple/swift/issues/66450), and the only workaround is to
  /// either move the extension to a separate file, or move the code from the extension to be
  /// directly inside the `State` type.
  ///
  /// ### CI build failures
  ///
  /// When testing your code on an external CI server you may run into errors such as the following:
  ///
  /// > Error: CasePathsMacros Target 'CasePathsMacros' must be enabled before it can be used.
  /// >
  /// > ComposableArchitectureMacros Target 'ComposableArchitectureMacros' must be enabled
  /// before it can be used.
  ///
  /// You can fix this in one of two ways. You can write a default to the CI machine that allows
  /// Xcode to skip macro validation:
  ///
  /// ```shell
  /// defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
  /// ```
  ///
  /// Or if you are invoking `xcodebuild` directly in your CI scripts, you can pass the
  ///  `-skipMacroValidation` flag to `xcodebuild` when building your project:
  ///
  /// ```shell
  /// xcodebuild -skipMacroValidation …
  /// ```
  @attached(
    member,
    names:
      named(State),
      named(Action),
      named(init),
      named(body)
  )
  @attached(memberAttribute)
  @attached(extension, conformances: Reducer)
  public macro Reducer() =
    #externalMacro(
      module: "ComposableArchitectureMacros", type: "ReducerMacro"
    )

  /// An overload of ``Reducer()`` that takes a description of protocol conformances to synthesize
  /// on the State and Action types
  ///
  /// See <doc:Reducer()#Synthesizing-protocol-conformances-on-State-and-Action> for more
  /// information.
  @attached(
    member,
    names:
      named(State),
      named(Action),
      named(init),
      named(body),
      named(CaseScope),
      named(scope)
  )
  @attached(memberAttribute)
  @attached(extension, conformances: Reducer, CaseReducer)
  public macro Reducer(state: _SynthesizedConformance..., action: _SynthesizedConformance...) =
    #externalMacro(
      module: "ComposableArchitectureMacros", type: "ReducerMacro"
    )

  #if swift(>=5.8)
    /// A description of a protocol conformance to synthesize on the State and Action types
    /// generated by the ``Reducer()`` macro.
    ///
    /// See <doc:Reducer()#Synthesizing-protocol-conformances-on-State-and-Action> for more
    /// information.
    @_documentation(visibility: public)
    public struct _SynthesizedConformance {}
  #else
    public struct _SynthesizedConformance {}
  #endif
    extension _SynthesizedConformance {
        /// Extends the `State` or `Action` types that ``Reducer(state:action:)`` creates with the
        /// `Codable` protocol.
        public static let codable = Self()
        /// Extends the `State` or `Action` types that ``Reducer(state:action:)`` creates with the
        /// `Decodable` protocol.
        public static let decodable = Self()
        /// Extends the `State` or `Action` types that ``Reducer(state:action:)`` creates with the
        /// `Encodable` protocol.
        public static let encodable = Self()
        /// Extends the `State` or `Action` types that ``Reducer(state:action:)`` creates with the
        /// `Equatable` protocol.
        public static let equatable = Self()
        /// Extends the `State` or `Action` types that ``Reducer(state:action:)`` creates with the
        /// `Hashable` protocol.
        public static let hashable = Self()
        /// Extends the `State` or `Action` types that ``Reducer(state:action:)`` creates with the
        /// `Sendable` protocol.
        public static let sendable = Self()
      }

  /// Marks the case of an enum reducer as holding onto "ephemeral" state.
  ///
  /// Apply this reducer to any cases of an enum reducer that holds onto state conforming to the
  /// ``ComposableArchitecture/_EphemeralState`` protocol, such as `AlertState` and
  /// `ConfirmationDialogState`:
  ///
  /// ```swift
  /// @Reducer
  /// enum Destination {
  ///   @ReducerEphemeralCase
  ///   case alert(AlertState<Alert>)
  ///   // ...
  ///
  ///   enum Alert {
  ///     case saveButtonTapped
  ///     case discardButtonTapped
  ///   }
  /// }
  /// ```
  @attached(peer, names: named(_))
  public macro ReducerCaseEphemeral() =
    #externalMacro(module: "ComposableArchitectureMacros", type: "ReducerCaseEphemeralMacro")

  /// Marks the case of an enum reducer as "ignored", and as such will not compose the case's
  /// domain into the rest of the reducer besides state.
  ///
  /// Apply this macro to cases that do not hold onto reducer features, and instead hold onto
  /// plain data that needs to be passed to a child view.
  ///
  /// ```swift
  /// @Reducer
  /// enum Destination {
  ///   @ReducerCaseIgnored
  ///   case meeting(id: Meeting.ID)
  ///   // ...
  /// }
  /// ```
  @attached(peer, names: named(_))
  public macro ReducerCaseIgnored() =
    #externalMacro(module: "ComposableArchitectureMacros", type: "ReducerCaseIgnoredMacro")

  /// Defines and implements conformance of the Observable protocol.
  @attached(extension, conformances: Observable, ObservableState)
  @attached(member, names: named(_$id), named(_$observationRegistrar), named(_$willModify))
  @attached(memberAttribute)
  public macro ObservableState() =
    #externalMacro(module: "ComposableArchitectureMacros", type: "ObservableStateMacro")

  @attached(accessor, names: named(init), named(get), named(set))
  @attached(peer, names: prefixed(_))
  public macro ObservationStateTracked() =
    #externalMacro(module: "ComposableArchitectureMacros", type: "ObservationStateTrackedMacro")

  @attached(accessor, names: named(willSet))
  public macro ObservationStateIgnored() =
    #externalMacro(module: "ComposableArchitectureMacros", type: "ObservationStateIgnoredMacro")

  /// Wraps a property with ``PresentationState`` and observes it.
  ///
  /// Use this macro instead of ``PresentationState`` when you adopt the ``ObservableState()``
  /// macro, which is incompatible with property wrappers like ``PresentationState``.
  @attached(accessor, names: named(init), named(get), named(set))
  @attached(peer, names: prefixed(`$`), prefixed(_))
  public macro Presents() =
    #externalMacro(module: "ComposableArchitectureMacros", type: "PresentsMacro")

  /// Provides a view with access to a feature's ``ViewAction``s.
  ///
  /// If you want to restrict what actions can be sent from the view you can use this macro along
  /// the ``ViewAction`` protocol. You start by conforming your reducer's `Action` enum to the
  /// ``ViewAction`` protocol, and moving view-specific actions to its own inner enum:
  ///
  /// ```swift
  /// @Reducer
  /// struct Feature {
  ///   struct State { /* ... */ }
  ///   enum Action: ViewAction {
  ///     case loginResponse(Bool)
  ///     case view(View)
  ///
  ///     enum View {
  ///       case loginButtonTapped
  ///     }
  ///   }
  ///   // ...
  /// }
  /// ```
  ///
  /// Then you can apply the ``ViewAction(for:)`` macro to your view by specifying the type of the
  /// reducer that powers the view:
  ///
  /// ```swift
  /// @ViewAction(for: Feature.self)
  /// struct FeatureView: View {
  ///   let store: StoreOf<Feature>
  ///   // ...
  /// }
  /// ```
  ///
  /// The macro does two things:
  ///
  /// * It adds a `send` method to the view that you can use instead of `store.send`. This allows
  /// you to send view actions more simply, without wrapping the action in `.view(…)`:
  ///   ```diff
  ///    Button("Login") {
  ///   -  store.send(.view(.loginButtonTapped))
  ///   +  send(.loginButtonTapped)
  ///    }
  ///   ```
  /// * It creates warning diagnostics if you try sending actions through `store.send` rather than
  /// using the `send` method on the view:
  ///   ```swift
  ///   Button("Login") {
  ///     store.send(.view(.loginButtonTapped))
  ///   //┬─────────
  ///   //╰─ ⚠️ Do not use 'store.send' directly when using '@ViewAction'
  ///   }
  ///   ```
  @attached(extension, conformances: ViewActionSending)
  public macro ViewAction<R: Reducer>(for: R.Type) =
    #externalMacro(
      module: "ComposableArchitectureMacros", type: "ViewActionMacro"
    ) where R.Action: ViewAction
#endif

