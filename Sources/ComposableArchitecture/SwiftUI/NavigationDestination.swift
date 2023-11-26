@_spi(Reflection) import CasePaths
import SwiftUI

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension View {
  /// Associates a destination view with a store that can be used to push the view onto a
  /// `NavigationStack`.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's
  /// > `navigationDestination(isPresented:)` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a screen. When `store`'s state is non-`nil`, the system passes a store of unwrapped
  ///     `State` and `Action` to the modifier's closure. You use this store to power the content
  ///     in a view that the system pushes onto the navigation stack. If `store`'s state is
  ///     `nil`-ed out, the system pops the view from the stack.
  ///   - destination: A closure returning the content of the destination view.
  public func navigationDestination<State, Action, Destination: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder destination: @escaping (_ store: Store<State, Action>) -> Destination
  ) -> some View {
    self._navigationDestination(
      store: store,
      state: { $0 },
      action: { $0 },
      destination: destination
    )
  }

  /// Associates a destination view with a store that can be used to push the view onto a
  /// `NavigationStack`.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's
  /// > `navigationDestination(isPresented:)` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a screen. When `store`'s state is non-`nil`, the system passes a store of unwrapped
  ///     `State` and `Action` to the modifier's closure. You use this store to power the content
  ///     in a view that the system pushes onto the navigation stack. If `store`'s state is
  ///     `nil`-ed out, the system pops the view from the stack.
  ///   - toDestinationState: A transformation to extract screen state from the presentation
  ///     state.
  ///   - fromDestinationAction: A transformation to embed screen actions into the presentation
  ///     action.
  ///   - destination: A closure returning the content of the destination view.
  @available(
    iOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    macOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    tvOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    watchOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  public func navigationDestination<
    State, Action, DestinationState, DestinationAction, Destination: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder destination: @escaping (_ store: Store<DestinationState, DestinationAction>) ->
      Destination
  ) -> some View {
    self._navigationDestination(
      store: store,
      state: toDestinationState,
      action: fromDestinationAction,
      destination: destination
    )
  }

  private func _navigationDestination<
    State, Action, DestinationState, DestinationAction, Destination: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder destination: @escaping (_ store: Store<DestinationState, DestinationAction>) ->
      Destination
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      id: { $0.wrappedValue.map(NavigationDestinationID.init) },
      action: fromDestinationAction
    ) { `self`, $item, destinationContent in
      self.navigationDestination(isPresented: $item.isPresent()) {
        destinationContent(destination)
      }
    }
  }
}

private struct NavigationDestinationID: Hashable {
  let objectIdentifier: ObjectIdentifier
  let enumTag: UInt32?

  init<Value>(_ value: Value) {
    self.objectIdentifier = ObjectIdentifier(Value.self)
    self.enumTag = EnumMetadata(Value.self)?.tag(of: value)
  }
}
