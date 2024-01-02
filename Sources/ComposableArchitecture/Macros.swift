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
  @attached(memberAttribute)
  @attached(extension, conformances: Reducer)
  public macro Reducer() =
    #externalMacro(
      module: "ComposableArchitectureMacros", type: "ReducerMacro"
    )

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
