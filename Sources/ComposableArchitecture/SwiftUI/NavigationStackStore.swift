import OrderedCollections
import SwiftUI

/// A navigation stack that is driven by a store.
///
/// This view can be used to drive stack-based navigation in the Composable Architecture when passed
/// a store that is focused on ``StackState`` and ``StackAction``.
///
/// See the dedicated article on <doc:Navigation> for more information on the library's navigation
/// tools, and in particular see <doc:StackBasedNavigation> for information on using this view.
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct NavigationStackStore<State, Action, Root: View, Destination: View>: View {
  private let root: Root
  private let destination: (Component<State>) -> Destination
  @ObservedObject private var viewStore: ViewStore<StackState<State>, StackAction<State, Action>>

  /// Creates a navigation stack with a store of stack state and actions.
  ///
  /// - Parameters:
  ///   - path: A store of stack state and actions to power this stack.
  ///   - root: The view to display when the stack is empty.
  ///   - destination: A view builder that defines a view to display when an element is appended to
  ///     the stack's state. The closure takes one argument, which is a store of the value to
  ///     present.
  public init(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
    @ViewBuilder root: () -> Root,
    @ViewBuilder destination: @escaping (_ store: Store<State, Action>) -> Destination
  ) {
    self.root = root()
    self.destination = { component in
      destination(
        store
          .scope(
            state: { $0[id: component.id]! },
            id: store.id(state: \.[id:component.id]!, action: \.[id:component.id]),
            action: { .element(id: component.id, action: $0) },
            isInvalid: { !$0.ids.contains(component.id) },
            removeDuplicates: nil
          )
      )
    }
    self._viewStore = ObservedObject(
      wrappedValue: ViewStore(
        store,
        observe: { $0 },
        removeDuplicates: { areOrderedSetsDuplicates($0.ids, $1.ids) }
      )
    )
  }

  /// Creates a navigation stack with a store of stack state and actions.
  ///
  /// - Parameters:
  ///   - path: A store of stack state and actions to power this stack.
  ///   - root: The view to display when the stack is empty.
  ///   - destination: A view builder that defines a view to display when an element is appended to
  ///     the stack's state. The closure takes one argument, which is the initial enum state to
  ///     present. You can switch over this value and use ``CaseLet`` views to handle each case.
  @_disfavoredOverload
  public init<D: View>(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
    @ViewBuilder root: () -> Root,
    @ViewBuilder destination: @escaping (_ initialState: State) -> D
  ) where Destination == SwitchStore<State, Action, D> {
    self.root = root()
    self.destination = { component in
      SwitchStore(
        store
          .scope(
            state: { $0[id: component.id]! },
            id: store.id(state: \.[id:component.id]!, action: \.[id:component.id]),
            action: { .element(id: component.id, action: $0) },
            isInvalid: { !$0.ids.contains(component.id) },
            removeDuplicates: nil
          )
      ) { _ in
        destination(component.element)
      }
    }
    self._viewStore = ObservedObject(
      wrappedValue: ViewStore(
        store,
        observe: { $0 },
        removeDuplicates: { areOrderedSetsDuplicates($0.ids, $1.ids) }
      )
    )
  }

  public var body: some View {
    NavigationStack(
      path: self.viewStore.binding(
        get: { $0.path },
        compactSend: { newPath in
          if newPath.count > self.viewStore.path.count, let component = newPath.last {
            return .push(id: component.id, state: component.element)
          } else if newPath.count < self.viewStore.path.count {
            return .popFrom(id: self.viewStore.path[newPath.count].id)
          } else {
            return nil
          }
        }
      )
    ) {
      self.root
        .environment(\.navigationDestinationType, State.self)
        .navigationDestination(for: Component<State>.self) { component in
          NavigationDestinationView(component: component, destination: self.destination)
        }
    }
  }
}

public struct _NavigationLinkStoreContent<State, Label: View>: View {
  let state: State?
  @ViewBuilder let label: Label
  let fileID: StaticString
  let line: UInt
  @Environment(\.navigationDestinationType) var navigationDestinationType

  public var body: some View {
    #if DEBUG
      self.label.onAppear {
        if self.navigationDestinationType != State.self {
          runtimeWarn(
            """
            A navigation link at "\(self.fileID):\(self.line)" is unpresentable. …

              NavigationStackStore element type:
                \(self.navigationDestinationType.map(typeName) ?? "(None found in view hierarchy)")
              NavigationLink state type:
                \(typeName(State.self))
              NavigationLink state value:
              \(String(customDumping: self.state).indent(by: 2))
            """
          )
        }
      }
    #else
      self.label
    #endif
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationLink where Destination == Never {
  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for a
  /// parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements that
  /// matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(value:label:)` for more.
  ///
  /// - Parameters:
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a copy
  ///     of the value. Pass a `nil` value to disable the link.
  ///   - label: A label that describes the view that this link presents.
  public init<P, L: View>(
    state: P?,
    @ViewBuilder label: () -> L,
    fileID: StaticString = #fileID,
    line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, L> {
    @Dependency(\.stackElementID) var stackElementID
    self.init(value: state.map { Component(id: stackElementID(), element: $0) }) {
      _NavigationLinkStoreContent<P, L>(
        state: state, label: { label() }, fileID: fileID, line: line
      )
    }
  }

  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``, with a text label that the link generates from a localized string key.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for a
  /// parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements that
  /// matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(_:value:)` for more.
  ///
  /// - Parameters:
  ///   - titleKey: A localized string that describes the view that this link
  ///     presents.
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a copy
  ///     of the value. Pass a `nil` value to disable the link.
  public init<P>(
    _ titleKey: LocalizedStringKey, state: P?, fileID: StaticString = #fileID, line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, Text> {
    self.init(state: state, label: { Text(titleKey) }, fileID: fileID, line: line)
  }

  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``, with a text label that the link generates from a title string.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for a
  /// parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements that
  /// matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(_:value:)` for more.
  ///
  /// - Parameters:
  ///   - title: A string that describes the view that this link presents.
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a copy
  ///     of the value. Pass a `nil` value to disable the link.
  @_disfavoredOverload
  public init<S: StringProtocol, P>(
    _ title: S, state: P?, fileID: StaticString = #fileID, line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, Text> {
    self.init(state: state, label: { Text(title) }, fileID: fileID, line: line)
  }
}

private struct NavigationDestinationView<State, Destination: View>: View {
  let component: Component<State>
  let destination: (Component<State>) -> Destination
  var body: some View {
    self.destination(self.component)
      .environment(\.navigationDestinationType, State.self)
      .id(self.component.id)
  }
}

private struct Component<Element>: Hashable {
  let id: StackElementID
  var element: Element

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

extension StackState {
  fileprivate var path: PathView {
    _read { yield PathView(base: self) }
    _modify {
      var path = PathView(base: self)
      yield &path
      self = path.base
    }
    set { self = newValue.base }
  }

  fileprivate struct PathView: MutableCollection, RandomAccessCollection,
    RangeReplaceableCollection
  {
    var base: StackState

    var startIndex: Int { self.base.startIndex }
    var endIndex: Int { self.base.endIndex }
    func index(after i: Int) -> Int { self.base.index(after: i) }
    func index(before i: Int) -> Int { self.base.index(before: i) }

    subscript(position: Int) -> Component<Element> {
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

    init() {
      self.init(base: StackState())
    }

    mutating func replaceSubrange<C: Collection>(
      _ subrange: Range<Int>, with newElements: C
    ) where C.Element == Component<Element> {
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
  fileprivate var navigationDestinationType: Any.Type? {
    get { self[NavigationDestinationTypeKey.self] }
    set { self[NavigationDestinationTypeKey.self] = newValue }
  }
}
