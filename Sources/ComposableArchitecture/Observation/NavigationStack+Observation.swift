import SwiftUI

extension Binding {
  /// Derives a binding to a store focused on ``StackState`` and ``StackAction``.
  ///
  /// This operator is most used in conjunction with `NavigationStack`, and in particular
  /// the initializer ``SwiftUI/NavigationStack/init(path:root:destination:fileID:filePath:line:column:)`` that
  /// ships with this library.
  ///
  /// For example, suppose you have a feature that holds onto ``StackState`` in its state in order
  /// to represent all the screens that can be pushed onto a navigation stack:
  ///
  /// ```swift
  /// @Reducer
  /// struct Feature {
  ///   @ObservableState
  ///   struct State {
  ///     var path: StackState<Path.State> = []
  ///   }
  ///   enum Action {
  ///     case path(StackActionOf<Path>)
  ///   }
  ///   var body: some ReducerOf<Self> {
  ///     Reduce { state, action in
  ///       // Core feature logic
  ///     }
  ///     .forEach(\.rows, action: \.rows) {
  ///       Child()
  ///     }
  ///   }
  ///   @Reducer
  ///   enum Path {
  ///     // ...
  ///   }
  /// }
  /// ```
  ///
  /// > Note: We are using the ``Reducer()`` macro on an enum to compose together all the features
  /// that can be pushed onto the stack. See <doc:Reducer#Destination-and-path-reducers> for
  /// more information.
  ///
  /// Then in the view you can use this operator, with
  /// `NavigationStack` ``SwiftUI/NavigationStack/init(path:root:destination:fileID:filePath:line:column:)``, to
  /// derive a store for each element in the stack:
  ///
  /// ```swift
  /// struct FeatureView: View {
  ///   @Bindable var store: StoreOf<Feature>
  ///
  ///   var body: some View {
  ///     NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
  ///       // Root view
  ///     } destination: {
  ///       // Destinations
  ///     }
  ///   }
  /// }
  /// ```
  #if swift(>=5.10)
    @preconcurrency@MainActor
  #else
    @MainActor(unsafe)
  #endif
  public func scope<State: ObservableState, Action, ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>
  where Value == Store<State, Action> {
    self[state: state, action: action]
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension SwiftUI.Bindable {
  /// Derives a binding to a store focused on ``StackState`` and ``StackAction``.
  ///
  /// See ``SwiftUI/Binding/scope(state:action:fileID:filePath:line:column:)`` defined on `Binding` for more
  /// information.
  #if swift(>=5.10)
    @preconcurrency@MainActor
  #else
    @MainActor(unsafe)
  #endif
  public func scope<State: ObservableState, Action, ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>
  where Value == Store<State, Action> {
    self[state: state, action: action]
  }
}

@available(iOS, introduced: 13, obsoleted: 17)
@available(macOS, introduced: 10.15, obsoleted: 14)
@available(tvOS, introduced: 13, obsoleted: 17)
@available(watchOS, introduced: 6, obsoleted: 10)
extension Perception.Bindable {
  /// Derives a binding to a store focused on ``StackState`` and ``StackAction``.
  ///
  /// See ``SwiftUI/Binding/scope(state:action:fileID:filePath:line:column:)`` defined on `Binding` for more
  /// information.
  public func scope<State: ObservableState, Action, ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>
  where Value == Store<State, Action> {
    self[state: state, action: action]
  }
}

extension UIBindable {
  /// Derives a binding to a store focused on ``StackState`` and ``StackAction``.
  ///
  /// See ``SwiftUI/Binding/scope(state:action:fileID:filePath:line:column:)`` defined on `Binding` for more
  /// information.
  #if swift(>=5.10)
    @preconcurrency@MainActor
  #else
    @MainActor(unsafe)
  #endif
  public func scope<State: ObservableState, Action, ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> UIBinding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>
  where Value == Store<State, Action> {
    self[state: state, action: action]
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationStack {
  /// Drives a navigation stack with a store.
  ///
  /// See the dedicated article on <doc:Navigation> for more information on the library's
  /// navigation tools, and in particular see <doc:StackBasedNavigation> for information on using
  /// this view.
  public init<State, Action, Destination: View, R>(
    path: Binding<Store<StackState<State>, StackAction<State, Action>>>,
    @ViewBuilder root: () -> R,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  )
  where
    Data == StackState<State>.PathView,
    Root == ModifiedContent<R, _NavigationDestinationViewModifier<State, Action, Destination>>
  {
    self.init(
      path: path[
        fileID: _HashableStaticString(rawValue: fileID),
        filePath: _HashableStaticString(rawValue: filePath),
        line: line,
        column: column
      ]
    ) {
      root()
        .modifier(
          _NavigationDestinationViewModifier(
            store: path.wrappedValue,
            destination: destination,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
          )
        )
    }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct _NavigationDestinationViewModifier<
  State: ObservableState, Action, Destination: View
>:
  ViewModifier
{
  @SwiftUI.State var store: Store<StackState<State>, StackAction<State, Action>>
  fileprivate let destination: (Store<State, Action>) -> Destination
  fileprivate let fileID: StaticString
  fileprivate let filePath: StaticString
  fileprivate let line: UInt
  fileprivate let column: UInt

  public func body(content: Content) -> some View {
    content
      .environment(\.navigationDestinationType, State.self)
      .navigationDestination(for: StackState<State>.Component.self) { component in
        var element = component.element
        self
          .destination(
            self.store.scope(
              id: self.store.id(
                state:
                  \.[
                    id: component.id,
                    fileID: _HashableStaticString(
                      rawValue: fileID),
                    filePath: _HashableStaticString(
                      rawValue: filePath), line: line, column: column
                  ],
                action: \.[id: component.id]
              ),
              state: ToState {
                element = $0[id: component.id] ?? element
                return element
              },
              action: { .element(id: component.id, action: $0) },
              isInvalid: { !$0.ids.contains(component.id) }
            )
          )
          .environment(\.navigationDestinationType, State.self)
      }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationLink where Destination == Never {
  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for
  /// a parent `NavigationStack` view with a store of ``StackState`` containing elements that
  /// matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(value:label:)` for more.
  ///
  /// - Parameters:
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a
  ///     copy of the value. Pass a `nil` value to disable the link.
  ///   - label: A label that describes the view that this link presents.
  #if compiler(>=6)
    @MainActor
  #endif
  public init<P, L: View>(
    state: P?,
    @ViewBuilder label: () -> L,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  )
  where Label == _NavigationLinkStoreContent<P, L> {
    @Dependency(\.stackElementID) var stackElementID
    self.init(value: state.map { StackState.Component(id: stackElementID(), element: $0) }) {
      _NavigationLinkStoreContent<P, L>(
        state: state,
        label: label,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
    }
  }

  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``, with a text label that the link generates from a localized string key.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for
  /// a parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements
  /// that matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(_:value:)` for more.
  ///
  /// - Parameters:
  ///   - titleKey: A localized string that describes the view that this link
  ///     presents.
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a
  ///     copy of the value. Pass a `nil` value to disable the link.
  #if compiler(>=6)
    @MainActor
  #endif
  public init<P>(
    _ titleKey: LocalizedStringKey, state: P?, fileID: StaticString = #fileID, line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, Text> {
    self.init(state: state, label: { Text(titleKey) }, fileID: fileID, line: line)
  }

  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``, with a text label that the link generates from a title string.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for
  /// a parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements
  /// that matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(_:value:)` for more.
  ///
  /// - Parameters:
  ///   - title: A string that describes the view that this link presents.
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a
  ///     copy of the value. Pass a `nil` value to disable the link.
  #if compiler(>=6)
    @MainActor
  #endif
  @_disfavoredOverload
  public init<S: StringProtocol, P>(
    _ title: S, state: P?, fileID: StaticString = #fileID, line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, Text> {
    self.init(state: state, label: { Text(title) }, fileID: fileID, line: line)
  }
}

public struct _NavigationLinkStoreContent<State, Label: View>: View {
  let state: State?
  @ViewBuilder let label: Label
  let fileID: StaticString
  let filePath: StaticString
  let line: UInt
  let column: UInt
  @Environment(\.navigationDestinationType) var navigationDestinationType

  @_spi(Internals)
  public init(
    state: State?,
    @ViewBuilder label: () -> Label,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
    self.state = state
    self.label = label()
    self.fileID = fileID
    self.filePath = filePath
    self.line = line
    self.column = column
  }

  public var body: some View {
    #if DEBUG
      label.onAppear {
        if navigationDestinationType != State.self {
          let elementType =
            navigationDestinationType.map { typeName($0) }
              ?? """
              (None found in view hierarchy. Is this link inside a store-powered \
              'NavigationStack'?)
              """
          reportIssue(
            """
            A navigation link at "\(fileID):\(line)" is unpresentable. …

              NavigationStack state element type:
                \(elementType)
              NavigationLink state type:
                \(typeName(State.self))
              NavigationLink state value:
              \(String(customDumping: state).indent(by: 2))
            """,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
          )
        }
      }
    #else
      label
    #endif
  }
}

extension Store where State: ObservableState {
  fileprivate subscript<ElementState, ElementAction>(
    state state: KeyPath<State, StackState<ElementState>>,
    action action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>,
    isInViewBody isInViewBody: Bool = _isInPerceptionTracking
  ) -> Store<StackState<ElementState>, StackAction<ElementState, ElementAction>> {
    get {
      #if DEBUG && !os(visionOS)
        _PerceptionLocals.$isInPerceptionTracking.withValue(isInViewBody) {
          self.scope(state: state, action: action)
        }
      #else
        self.scope(state: state, action: action)
      #endif
    }
    set {}
  }
}

extension Store {
  @_spi(Internals)
  public subscript<ElementState, ElementAction>(
    fileID fileID: _HashableStaticString,
    filePath filePath: _HashableStaticString,
    line line: UInt,
    column column: UInt
  ) -> StackState<ElementState>.PathView
  where State == StackState<ElementState>, Action == StackAction<ElementState, ElementAction> {
    get { self.currentState.path }
    set {
      let newCount = newValue.count
      guard newCount != self.currentState.count else {
        reportIssue(
          """
          A navigation stack binding at "\(fileID.rawValue):\(line)" was written to with a \
          path that has the same number of elements that already exist in the store. A view \
          should only write to this binding with a path that has pushed a new element onto the \
          stack, or popped one or more elements from the stack.

          This usually means the "forEach" has not been integrated with the reducer powering the \
          store, and this reducer is responsible for handling stack actions.

          To fix this, ensure that "forEach" is invoked from the reducer's "body":

              Reduce { state, action in
                // ...
              }
              .forEach(\\.path, action: \\.path) {
                Path()
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
      if newCount > self.currentState.count, let component = newValue.last {
        self.send(.push(id: component.id, state: component.element))
      } else {
        self.send(.popFrom(id: self.currentState.ids[newCount]))
      }
    }
  }
}

@_spi(Internals)
public var _isInPerceptionTracking: Bool {
  #if !os(visionOS)
    return _PerceptionLocals.isInPerceptionTracking
  #else
    return false
  #endif
}

extension StackState {
  var path: PathView {
    _read { yield PathView(base: self) }
    _modify {
      var path = PathView(base: self)
      yield &path
      self = path.base
    }
    set { self = newValue.base }
  }

  public struct Component: Hashable {
    @_spi(Internals)
    public let id: StackElementID
    @_spi(Internals)
    public var element: Element

    @_spi(Internals)
    public init(id: StackElementID, element: Element) {
      self.id = id
      self.element = element
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.id)
    }
  }

  public struct PathView: MutableCollection, RandomAccessCollection,
    RangeReplaceableCollection
  {
    var base: StackState

    public var startIndex: Int { self.base.startIndex }
    public var endIndex: Int { self.base.endIndex }
    public func index(after i: Int) -> Int { self.base.index(after: i) }
    public func index(before i: Int) -> Int { self.base.index(before: i) }

    public subscript(position: Int) -> Component {
      _read {
        yield Component(id: self.base.ids[position], element: self.base[position])
      }
      _modify {
        let id = self.base.ids[position]
        var component = Component(id: id, element: self.base[position])
        yield &component
        self.base[id: id] = component.element
      }
      set {
        self.base[id: newValue.id] = newValue.element
      }
    }

    init(base: StackState) {
      self.base = base
    }

    public init() {
      self.init(base: StackState())
    }

    public mutating func replaceSubrange(
      _ subrange: Range<Int>, with newElements: some Collection<Component>
    ) {
      for id in self.base.ids[subrange] {
        self.base[id: id] = nil
      }
      for component in newElements.reversed() {
        self.base._dictionary
          .updateValue(component.element, forKey: component.id, insertingAt: subrange.lowerBound)
      }
    }
  }
}

private struct NavigationDestinationTypeKey: EnvironmentKey {
  static var defaultValue: Any.Type? { nil }
}

extension EnvironmentValues {
  @_spi(Internals)
  public var navigationDestinationType: Any.Type? {
    get { self[NavigationDestinationTypeKey.self] }
    set { self[NavigationDestinationTypeKey.self] = newValue }
  }
}
