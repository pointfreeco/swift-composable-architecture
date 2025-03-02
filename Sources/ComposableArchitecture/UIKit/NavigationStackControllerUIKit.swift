#if canImport(UIKit) && !os(watchOS)
  import UIKit

  extension NavigationStackController {
    /// Drives a navigation stack controller with a store.
    ///
    /// See the dedicated article on <doc:Navigation> for more information on the library's
    /// navigation tools, and in particular see <doc:StackBasedNavigation> for information on using
    /// this view.
    ///
    /// - Parameters:
    ///   - navigationBarClass: Specify the custom `UINavigationBar` subclass you want to use, or
    ///     specify `nil` to use the standard `UINavigationBar` class.
    ///   - toolbarClass: Specify the custom `UIToolbar` subclass you want to use, or specify `nil`
    ///     to use the standard `UIToolbar` class.
    ///   - path: A binding to a store of stack state.
    ///   - root: A root view controller.
    ///   - destination: A function to create a `UIViewController` from a store.
    ///   - fileID: The source `#fileID` associated with the controller.
    ///   - filePath: The source `#filePath` associated with the controller.
    ///   - line: The source `#line` associated with the controller.
    ///   - column: The source `#column` associated with the controller.
    public convenience init<State, Action>(
      navigationBarClass: AnyClass? = nil,
      toolbarClass: AnyClass? = nil,
      path: UIBinding<Store<StackState<State>, StackAction<State, Action>>>,
      root: () -> UIViewController,
      destination: @escaping (Store<State, Action>) -> UIViewController,
      fileID: StaticString = #fileID,
      filePath: StaticString = #filePath,
      line: UInt = #line,
      column: UInt = #column
    ) {
      self.init(
        navigationBarClass: navigationBarClass,
        toolbarClass: toolbarClass,
        path: path[
          fileID: _HashableStaticString(rawValue: fileID),
          filePath: _HashableStaticString(rawValue: filePath),
          line: line,
          column: column
        ],
        root: root
      )
      navigationDestination(for: StackState<State>.Component.self) { component in
        var element = component.element
        return destination(
          path.wrappedValue.scope(
            id: path.wrappedValue.id(
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
      }
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  @MainActor
  extension UIPushAction {
    /// Pushes an element of ``StackState`` onto the current navigation stack.
    ///
    /// This is the UIKit equivalent of
    /// ``SwiftUI/NavigationLink/init(state:label:fileID:filePath:line:column:)``.
    ///
    /// - Parameters:
    ///   - state: An element of stack state.
    ///   - fileID: The source `#fileID` associated with the push.
    ///   - filePath: The source `#filePath` associated with the push.
    ///   - line: The source `#line` associated with the push.
    ///   - column: The source `#column` associated with the push.
    public func callAsFunction<Element: Hashable>(
      state: Element,
      fileID: StaticString = #fileID,
      filePath: StaticString = #filePath,
      line: UInt = #line,
      column: UInt = #column
    ) {
      @Dependency(\.stackElementID) var stackElementID
      self(
        value: StackState.Component(id: stackElementID(), element: state),
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
    }
  }
#endif
