import SwiftUI

/// A property wrapper type that can designate properties of view state that can be directly
/// bindable in SwiftUI views.
///
/// Read <doc:Bindings> for more information.
@dynamicMemberLookup
@propertyWrapper
public struct BindingViewState<Value> {
  let binding: Binding<Value>
  let initialValue: Value

  init(binding: Binding<Value>) {
    self.binding = binding
    self.initialValue = binding.wrappedValue
  }

  public var wrappedValue: Value {
    get { self.binding.wrappedValue }
    set { self.binding.wrappedValue = newValue }
  }

  public var projectedValue: Binding<Value> {
    self.binding
  }

  public subscript<Subject>(
    dynamicMember keyPath: WritableKeyPath<Value, Subject>
  ) -> BindingViewState<Subject> {
    BindingViewState<Subject>(binding: self.binding[dynamicMember: keyPath])
  }
}

extension BindingViewState: Equatable where Value: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.initialValue == rhs.initialValue && lhs.wrappedValue == rhs.wrappedValue
  }
}

extension BindingViewState: Hashable where Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.initialValue)
    hasher.combine(self.wrappedValue)
  }
}

extension BindingViewState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue)
  }
}

extension BindingViewState: CustomDumpRepresentable {
  public var customDumpValue: Any {
    self.wrappedValue
  }
}

extension BindingViewState: CustomDebugStringConvertible
where Value: CustomDebugStringConvertible {
  public var debugDescription: String {
    self.wrappedValue.debugDescription
  }
}


extension ViewStore {
  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - fromViewAction: A function that transforms view actions into store action.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed.
  public convenience init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: { (_: State) in
        toViewState(BindingViewStore(store: store.scope(state: { $0 }, action: fromViewAction)))
      },
      send: fromViewAction,
      removeDuplicates: isDuplicate
    )
  }

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed.
  @_disfavoredOverload
  public convenience init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      send: { $0 },
      removeDuplicates: isDuplicate
    )
  }
}

extension ViewStore where ViewState: Equatable {
  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - fromViewAction: A function that transforms view actions into store action.
  @_disfavoredOverload
  public convenience init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      send: fromViewAction,
      removeDuplicates: ==
    )
  }

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public convenience init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      removeDuplicates: ==
    )
  }
}

extension WithViewStore where Content: View {
  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings and views from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - fromViewAction: A function that transforms view actions into store action.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: { (_: State) in
        toViewState(BindingViewStore(store: store.scope(state: { $0 }, action: fromViewAction)))
      },
      send: fromViewAction,
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings and views from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      send: { $0 },
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

extension WithViewStore where ViewState: Equatable, Content: View {
  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings and views from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - fromViewAction: A function that transforms view actions into store action.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      send: fromViewAction,
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings and views from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }
}
