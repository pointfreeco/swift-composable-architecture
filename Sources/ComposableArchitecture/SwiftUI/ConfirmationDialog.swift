import SwiftUI

extension View {
  /// Displays a dialog when the store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that describes if the dialog is shown or dismissed.
  ///   - dismissal: An action to send when the dialog is dismissed through non-user actions, such
  ///     as when a dialog is automatically dismissed by the system. Use this action to `nil` out
  ///     the associated dialog state.
  @available(iOS 13, *)
  @available(macOS 12, *)
  @available(tvOS 13, *)
  @available(watchOS 6, *)
  @ViewBuilder public func confirmationDialog<Action>(
    _ store: Store<ConfirmationDialogState<Action>?, Action>,
    dismiss: Action
  ) -> some View {
    if #available(iOS 15, tvOS 15, watchOS 8, *) {
      self.modifier(
        NewConfirmationDialogModifier(
          viewStore: ViewStore(store, removeDuplicates: { $0?.id == $1?.id }),
          dismiss: dismiss
        )
      )
    } else {
      #if !os(macOS)
        self.modifier(
          OldConfirmationDialogModifier(
            viewStore: ViewStore(store, removeDuplicates: { $0?.id == $1?.id }),
            dismiss: dismiss
          )
        )
      #endif
    }
  }
}

// NB: Workaround for iOS 14 runtime crashes during iOS 15 availability checks.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
private struct NewConfirmationDialogModifier<Action>: ViewModifier {
  @ObservedObject var viewStore: ViewStore<ConfirmationDialogState<Action>?, Action>
  let dismiss: Action

  func body(content: Content) -> some View {
    content.confirmationDialog(
      (viewStore.state?.title).map { Text($0) } ?? Text(""),
      isPresented: viewStore.binding(send: dismiss).isPresent(),
      titleVisibility: viewStore.state.map { .init($0.titleVisibility) } ?? .automatic,
      presenting: viewStore.state,
      actions: {
        ForEach($0.buttons) {
          Button($0, action: { viewStore.send($0) })
        }
      },
      message: { $0.message.map { Text($0) } }
    )
  }
}

@available(iOS 13, *)
@available(macOS 12, *)
@available(tvOS 13, *)
@available(watchOS 6, *)
private struct OldConfirmationDialogModifier<Action>: ViewModifier {
  @ObservedObject var viewStore: ViewStore<ConfirmationDialogState<Action>?, Action>
  let dismiss: Action

  func body(content: Content) -> some View {
    #if !os(macOS)
      return content.actionSheet(item: viewStore.binding(send: dismiss)) {
        ActionSheet($0) { viewStore.send($0) }
      }
    #else
      return EmptyView()
    #endif
  }
}
