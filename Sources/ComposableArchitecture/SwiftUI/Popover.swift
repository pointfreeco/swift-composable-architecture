import SwiftUI

@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension View {
  /// Presents a popover using the given store as a data source for the popover's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `popover` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a modal. When `store`'s state is non-`nil`, the system passes a store of unwrapped `State`
  ///     and `Action` to the modifier's closure. You use this store to power the content in a
  ///     popover you create that the system displays to the user. If `store`'s state is `nil`-ed
  ///     out, the system dismisses the currently displayed popover.
  ///   - attachmentAnchor: The positioning anchor that defines the attachment point of the popover.
  ///   - arrowEdge: The edge of the `attachmentAnchor` that defines the location of the popover's
  ///     arrow in macOS. iOS ignores this parameter.
  ///   - content: A closure returning the content of the popover.
  @available(
    iOS, deprecated: 9999,
    message:
      "Pass a binding of a store to 'popover(item:)' instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers]"
  )
  @available(
    macOS, deprecated: 9999,
    message:
      "Pass a binding of a store to 'popover(item:)' instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers]"
  )
  @available(
    tvOS, deprecated: 9999,
    message:
      "Pass a binding of a store to 'popover(item:)' instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers]"
  )
  @available(
    watchOS, deprecated: 9999,
    message:
      "Pass a binding of a store to 'popover(item:)' instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers]"
  )
  public func popover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (_ store: Store<State, Action>) -> Content
  ) -> some View {
    self.presentation(store: store) { `self`, $item, destination in
      self.popover(item: $item, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge) { _ in
        destination(content)
      }
    }
  }

  /// Presents a popover using the given store as a data source for the popover's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `popover` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a modal. When `store`'s state is non-`nil`, the system passes a store of unwrapped `State`
  ///     and `Action` to the modifier's closure. You use this store to power the content in a
  ///     popover you create that the system displays to the user. If `store`'s state is `nil`-ed
  ///     out, the system dismisses the currently displayed popover.
  ///   - toDestinationState: A transformation to extract popover state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed popover actions into the presentation
  ///     action.
  ///   - attachmentAnchor: The positioning anchor that defines the attachment point of the popover.
  ///   - arrowEdge: The edge of the `attachmentAnchor` that defines the location of the popover's
  ///     arrow in macOS. iOS ignores this parameter.
  ///   - content: A closure returning the content of the popover.
  @available(
    iOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    macOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    tvOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    watchOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  public func popover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (_ store: Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $item, destination in
      self.popover(item: $item, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge) { _ in
        destination(content)
      }
    }
  }
}
