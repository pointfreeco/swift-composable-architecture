#if canImport(Perception)
  import SwiftUI

  #if canImport(Observation)
    import Observation
  #endif

  #if !os(visionOS)
    extension Store: Perceptible {}
  #endif

  extension Store where State: ObservableState {
    var observableState: State {
      self._$observationRegistrar.access(self, keyPath: \.currentState)
      return self.currentState
    }

    /// Direct access to state in the store when `State` conforms to ``ObservableState``.
    public var state: State {
      self.observableState
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
      self.state[keyPath: keyPath]
    }
  }

  extension Store: Equatable {
    public static func == (lhs: Store, rhs: Store) -> Bool {
      lhs === rhs
    }
  }

  extension Store: Hashable {
    public func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self))
    }
  }

  extension Store: Identifiable {}

  extension Store where State: ObservableState {
    /// Scopes the store to optional child state and actions.
    ///
    /// If your feature holds onto a child feature as an optional:
    ///
    /// ```swift
    /// @Reducer
    /// struct Feature {
    ///   @ObservableState
    ///   struct State {
    ///     var child: Child.State?
    ///     // ...
    ///   }
    ///   enum Action {
    ///     case child(Child.Action)
    ///     // ...
    ///   }
    ///   // ...
    /// }
    /// ```
    ///
    /// …then you can use this `scope` operator in order to transform a store of your feature into
    /// a non-optional store of the child domain:
    ///
    /// ```swift
    /// if let childStore = store.scope(state: \.child, action: \.child) {
    ///   ChildView(store: childStore)
    /// }
    /// ```
    ///
    /// > Important: This operation should only be used from within a SwiftUI view or within
    /// > `withPerceptionTracking` in order for changes of the optional state to be properly
    /// > observed.
    ///
    /// - Parameters:
    ///   - state: A key path to optional child state.
    ///   - action: A case key path to child actions.
    /// - Returns: An optional store of non-optional child state and actions.
    public func scope<ChildState, ChildAction>(
      state: KeyPath<State, ChildState?>,
      action: CaseKeyPath<Action, ChildAction>,
      fileID: StaticString = #fileID,
      filePath: StaticString = #filePath,
      line: UInt = #line,
      column: UInt = #column
    ) -> Store<ChildState, ChildAction>? {
      if !self.canCacheChildren {
        reportIssue(
          uncachedStoreWarning(self),
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
      }
      guard var childState = self.state[keyPath: state]
      else { return nil }
      return self.scope(
        id: self.id(state: state.appending(path: \.!), action: action),
        state: ToState {
          childState = $0[keyPath: state] ?? childState
          return childState
        },
        action: { action($0) },
        isInvalid: { $0[keyPath: state] == nil }
      )
    }
  }

  extension Binding {
    /// Scopes the binding of a store to a binding of an optional presentation store.
    ///
    /// Use this operator to derive a binding that can be handed to SwiftUI's various navigation
    /// view modifiers, such as `sheet(item:)`, popover(item:)`, etc.
    ///
    ///
    /// For example, suppose your feature can present a child feature in a sheet. Then your feature's
    /// domain would hold onto the child's domain using the library's presentation tools (see
    /// <doc:TreeBasedNavigation> for more information on these tools):
    ///
    /// ```swift
    /// @Reducer
    /// struct Feature {
    ///   @ObservableState
    ///   struct State {
    ///     @Presents var child: Child.State?
    ///     // ...
    ///   }
    ///   enum Action {
    ///     case child(PresentationActionOf<Child>)
    ///     // ...
    ///   }
    ///   // ...
    /// }
    /// ```
    ///
    /// Then you can derive a binding to the child domain that can be handed to the `sheet(item:)`
    /// view modifier:
    ///
    /// ```swift
    /// struct FeatureView: View {
    ///   @Bindable var store: StoreOf<Feature>
    ///
    ///   var body: some View {
    ///     // ...
    ///     .sheet(item: $store.scope(state: \.child, action: \.child)) { store in
    ///       ChildView(store: store)
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - state: A key path to optional child state.
    ///   - action: A case key path to presentation child actions.
    /// - Returns: A binding of an optional child store.
    public func scope<State: ObservableState, Action, ChildState, ChildAction>(
      state: KeyPath<State, ChildState?>,
      action: CaseKeyPath<Action, PresentationAction<ChildAction>>,
      fileID: StaticString = #fileID,
      filePath: StaticString = #fileID,
      line: UInt = #line,
      column: UInt = #column
    ) -> Binding<Store<ChildState, ChildAction>?>
    where Value == Store<State, Action> {
      self[
        state: state,
        action: action,
        isInViewBody: _isInPerceptionTracking,
        fileID: _HashableStaticString(rawValue: fileID),
        filePath: _HashableStaticString(rawValue: filePath),
        line: line,
        column: column
      ]
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  extension SwiftUI.Bindable {
    /// Scopes the binding of a store to a binding of an optional presentation store.
    ///
    /// Use this operator to derive a binding that can be handed to SwiftUI's various navigation
    /// view modifiers, such as `sheet(item:)`, popover(item:)`, etc.
    ///
    ///
    /// For example, suppose your feature can present a child feature in a sheet. Then your
    /// feature's domain would hold onto the child's domain using the library's presentation tools
    /// (see <doc:TreeBasedNavigation> for more information on these tools):
    ///
    /// ```swift
    /// @Reducer
    /// struct Feature {
    ///   @ObservableState
    ///   struct State {
    ///     @Presents var child: Child.State?
    ///     // ...
    ///   }
    ///   enum Action {
    ///     case child(PresentationActionOf<Child>)
    ///     // ...
    ///   }
    ///   // ...
    /// }
    /// ```
    ///
    /// Then you can derive a binding to the child domain that can be handed to the `sheet(item:)`
    /// view modifier:
    ///
    /// ```swift
    /// struct FeatureView: View {
    ///   @Bindable var store: StoreOf<Feature>
    ///
    ///   var body: some View {
    ///     // ...
    ///     .sheet(item: $store.scope(state: \.child, action: \.child)) { store in
    ///       ChildView(store: store)
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - state: A key path to optional child state.
    ///   - action: A case key path to presentation child actions.
    /// - Returns: A binding of an optional child store.
    public func scope<State: ObservableState, Action, ChildState, ChildAction>(
      state: KeyPath<State, ChildState?>,
      action: CaseKeyPath<Action, PresentationAction<ChildAction>>,
      fileID: StaticString = #fileID,
      filePath: StaticString = #fileID,
      line: UInt = #line,
      column: UInt = #column
    ) -> Binding<Store<ChildState, ChildAction>?>
    where Value == Store<State, Action> {
      self[
        state: state,
        action: action,
        isInViewBody: _isInPerceptionTracking,
        fileID: _HashableStaticString(rawValue: fileID),
        filePath: _HashableStaticString(rawValue: filePath),
        line: line,
        column: column
      ]
    }
  }

  @available(iOS, introduced: 13, obsoleted: 17)
  @available(macOS, introduced: 10.15, obsoleted: 14)
  @available(tvOS, introduced: 13, obsoleted: 17)
  @available(watchOS, introduced: 6, obsoleted: 10)
  extension Perception.Bindable {
    /// Scopes the binding of a store to a binding of an optional presentation store.
    ///
    /// Use this operator to derive a binding that can be handed to SwiftUI's various navigation
    /// view modifiers, such as `sheet(item:)`, popover(item:)`, etc.
    ///
    ///
    /// For example, suppose your feature can present a child feature in a sheet. Then your
    /// feature's domain would hold onto the child's domain using the library's presentation tools
    /// (see <doc:TreeBasedNavigation> for more information on these tools):
    ///
    /// ```swift
    /// @Reducer
    /// struct Feature {
    ///   @ObservableState
    ///   struct State {
    ///     @Presents var child: Child.State?
    ///     // ...
    ///   }
    ///   enum Action {
    ///     case child(PresentationActionOf<Child>)
    ///     // ...
    ///   }
    ///   // ...
    /// }
    /// ```
    ///
    /// Then you can derive a binding to the child domain that can be handed to the `sheet(item:)`
    /// view modifier:
    ///
    /// ```swift
    /// struct FeatureView: View {
    ///   @Bindable var store: StoreOf<Feature>
    ///
    ///   var body: some View {
    ///     // ...
    ///     .sheet(item: $store.scope(state: \.child, action: \.child)) { store in
    ///       ChildView(store: store)
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - state: A key path to optional child state.
    ///   - action: A case key path to presentation child actions.
    /// - Returns: A binding of an optional child store.
    public func scope<State: ObservableState, Action, ChildState, ChildAction>(
      state: KeyPath<State, ChildState?>,
      action: CaseKeyPath<Action, PresentationAction<ChildAction>>,
      fileID: StaticString = #fileID,
      filePath: StaticString = #filePath,
      line: UInt = #line,
      column: UInt = #column
    ) -> Binding<Store<ChildState, ChildAction>?>
    where Value == Store<State, Action> {
      self[
        state: state,
        action: action,
        isInViewBody: _isInPerceptionTracking,
        fileID: _HashableStaticString(rawValue: fileID),
        filePath: _HashableStaticString(rawValue: filePath),
        line: line,
        column: column
      ]
    }
  }

  extension Store where State: ObservableState {
    @_spi(Internals)
    public subscript<ChildState, ChildAction>(
      state state: KeyPath<State, ChildState?>,
      action action: CaseKeyPath<Action, PresentationAction<ChildAction>>,
      isInViewBody isInViewBody: Bool,
      fileID fileID: _HashableStaticString,
      filePath filePath: _HashableStaticString,
      line line: UInt,
      column column: UInt
    ) -> Store<ChildState, ChildAction>? {
      get {
        #if DEBUG && !os(visionOS)
          _PerceptionLocals.$isInPerceptionTracking.withValue(isInViewBody) {
            self.scope(
              state: state,
              action: action.appending(path: \.presented),
              fileID: fileID.rawValue,
              filePath: filePath.rawValue,
              line: line,
              column: column
            )
          }
        #else
          self.scope(
            state: state,
            action: action.appending(path: \.presented),
            fileID: fileID.rawValue,
            filePath: filePath.rawValue,
            line: line,
            column: column
          )
        #endif
      }
      set {
        if newValue == nil, self.state[keyPath: state] != nil, !self._isInvalidated() {
          self.send(action(.dismiss))
          if self.state[keyPath: state] != nil {
            reportIssue(
              """
              SwiftUI dismissed a view through a binding at "\(fileID):\(line)", but the store \
              destination wasn't set to "nil".

              This usually means an "ifLet" has not been integrated with the reducer powering the \
              store, and this reducer is responsible for handling presentation actions.

              To fix this, ensure that "ifLet" is invoked from the reducer's "body":

                  Reduce { state, action in
                    // ...
                  }
                  .ifLet(\\.destination, action: \\.destination) {
                    Destination()
                  }

              And ensure that every parent reducer is integrated into the root reducer that powers \
              the store.
              """,
              fileID: fileID.rawValue,
              filePath: filePath.rawValue,
              line: line,
              column: column
            )
            return
          }
        }
      }
    }
  }

  func uncachedStoreWarning<State, Action>(_ store: Store<State, Action>) -> String {
    """
    Scoping from uncached \(store) is not compatible with observation.

    This can happen for one of two reasons:

    • A parent view scopes on a store using transform functions, which has been \
    deprecated, instead of with key paths and case paths. Read the migration guide for 1.5 \
    to update these scopes: https://pointfreeco.github.io/swift-composable-architecture/\
    main/documentation/composablearchitecture/migratingto1.5

    • A parent feature is using deprecated navigation APIs, such as 'IfLetStore', \
    'SwitchStore', 'ForEachStore', or any navigation view modifiers taking stores instead of \
    bindings. Read the migration guide for 1.7 to update those APIs: \
    https://pointfreeco.github.io/swift-composable-architecture/main/documentation/\
    composablearchitecture/migratingto1.7
    """
  }

#endif
