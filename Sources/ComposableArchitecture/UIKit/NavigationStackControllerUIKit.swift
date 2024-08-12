#if canImport(UIKit)
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
    ///   - toolbarClass: Specify the custom `UIToolbar` subclass you want to use, or specify `nil` to
    ///     use the standard `UIToolbar` class.
    ///   - path: A binding to a store of stack state.
    ///   - root: A root view controller.
    ///   - fileID: The source `#fileID` associated with the controller.
    ///   - filePath: The source `#filePath` associated with the controller.
    ///   - line: The source `#line` associated with the controller.
    ///   - column: The source `#column` associated with the controller.
    public convenience init<State, Action>(
      navigationBarClass: AnyClass? = nil,
      toolbarClass: AnyClass? = nil,
      path: UIBinding<Store<StackState<State>, StackAction<State, Action>>>,
      root: () -> UIViewController,
      fileID: StaticString = #fileID,
      filePath: StaticString = #filePath,
      line: UInt = #line,
      column: UInt = #column
    ) where Data.Element: Hashable {
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
    }
  }
#endif
