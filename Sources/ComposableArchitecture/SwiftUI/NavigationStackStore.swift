import OrderedCollections
import SwiftUI

/// A navigation stack that is driven by a store.
///
/// This view can be used to drive stack-based navigation in the Composable Architecture when passed
/// a store that is focused on ``StackState`` and ``StackAction``.
///
/// See the dedicated article on <doc:Navigation> for more information on the library's navigation
/// tools, and in particular see <doc:StackBasedNavigation> for information on using this view.
@available(
  iOS, deprecated: 9999,
  message:
    "Use 'NavigationStack.init(path:)' with a store scoped from observable state, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-NavigationStackStore-with-NavigationStack]"
)
@available(
  macOS, deprecated: 9999,
  message:
    "Use 'NavigationStack.init(path:)' with a store scoped from observable state, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-NavigationStackStore-with-NavigationStack]"
)
@available(
  tvOS, deprecated: 9999,
  message:
    "Use 'NavigationStack.init(path:)' with a store scoped from observable state, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-NavigationStackStore-with-NavigationStack]"
)
@available(
  watchOS, deprecated: 9999,
  message:
    "Use 'NavigationStack.init(path:)' with a store scoped from observable state, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-NavigationStackStore-with-NavigationStack]"
)
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct NavigationStackStore<State, Action, Root: View, Destination: View>: View {
  private let root: Root
  private let destination: (StackState<State>.Component) -> Destination
  @ObservedObject private var viewStore: ViewStore<StackState<State>, StackAction<State, Action>>

  /// Creates a navigation stack with a store of stack state and actions.
  ///
  /// - Parameters:
  ///   - store: A store of stack state and actions to power this stack.
  ///   - root: The view to display when the stack is empty.
  ///   - destination: A view builder that defines a view to display when an element is appended to
  ///     the stack's state. The closure takes one argument, which is a store of the value to
  ///     present.
  ///   - fileID: The fileID.
  ///   - filePath: The filePath.
  ///   - line: The line.
  ///   - column: The column.
  public init(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
    @ViewBuilder root: () -> Root,
    @ViewBuilder destination: @escaping (_ store: Store<State, Action>) -> Destination,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) {
    self.root = root()
    self.destination = { component in
      var element = component.element
      return destination(
        store
          .scope(
            id: store.id(
              state:
                \.[
                  id: component.id,
                  fileID: _HashableStaticString(
                    rawValue: fileID),
                  filePath: _HashableStaticString(
                    rawValue: filePath), line: line, column: column
                ]!,
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
  ///   - store: A store of stack state and actions to power this stack.
  ///   - root: The view to display when the stack is empty.
  ///   - destination: A view builder that defines a view to display when an element is appended to
  ///     the stack's state. The closure takes one argument, which is the initial enum state to
  ///     present. You can switch over this value and use ``CaseLet`` views to handle each case.
  ///   - fileID: The fileID.
  ///   - filePath: The filePath.
  ///   - line: The line.
  ///   - column: The column.
  @_disfavoredOverload
  public init<D: View>(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
    @ViewBuilder root: () -> Root,
    @ViewBuilder destination: @escaping (_ initialState: State) -> D,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) where Destination == SwitchStore<State, Action, D> {
    self.root = root()
    self.destination = { component in
      var element = component.element
      return SwitchStore(
        store
          .scope(
            id: store.id(
              state:
                \.[
                  id: component.id,
                  fileID: _HashableStaticString(
                    rawValue: fileID),
                  filePath: _HashableStaticString(
                    rawValue: filePath), line: line, column: column
                ]!,
              action: \.[id: component.id]
            ),
            state: ToState {
              element = $0[id: component.id] ?? element
              return element
            },
            action: { .element(id: component.id, action: $0) },
            isInvalid: { !$0.ids.contains(component.id) }
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
        .navigationDestination(for: StackState<State>.Component.self) { component in
          NavigationDestinationView(component: component, destination: self.destination)
        }
    }
  }
}

private struct NavigationDestinationView<State, Destination: View>: View {
  let component: StackState<State>.Component
  let destination: (StackState<State>.Component) -> Destination
  var body: some View {
    self.destination(self.component)
      .environment(\.navigationDestinationType, State.self)
      .id(self.component.id)
  }
}
