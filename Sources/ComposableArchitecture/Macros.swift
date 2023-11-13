#if swift(>=5.9)
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
  ///    // …
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
  ///    // …
  ///  }
  /// ```
  ///
  /// This will allow you to use key path syntax for specifying case paths to the `State`'s cases,
  /// as well as allow you to use dot-chaining syntax for optionally extracting a case from the
  /// state. This can be useful when using the view modifiers that come with the library that allow
  /// for driving navigation from an enum of options:
  ///
  /// ```swift
  /// .sheet(
  ///   store: self.store.scope(state: \.destination, action: \.destination)
  ///   state: \.editForm,
  ///   action: { .editForm($0) }
  /// )
  /// ```
  ///
  /// The syntax `state: \.editForm` is only possible due to both `@dynamicMemberLookup` and
  /// `@CasePathable` being applied to the `State` enum.
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
  @attached(memberAttribute)
  @attached(extension, conformances: Reducer)
  public macro Reducer() =
    #externalMacro(
      module: "ComposableArchitectureMacros", type: "ReducerMacro"
    )
#endif
