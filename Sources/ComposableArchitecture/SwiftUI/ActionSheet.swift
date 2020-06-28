import SwiftUI

/// A data type that describes the state of an action sheet that can be shown to the user. The
/// `Action` generic is the type of actions that can be sent from tapping on a button in the sheet.
///
/// This type can be used in your application's state in order to control the presentation or
/// dismissal of action sheets. It is preferrable to use this API instead of the default SwiftUI API
/// for action sheets because SwiftUI uses 2-way bindings in order to control the showing and
/// dismissal of sheets, and that does not play nicely with the Composable Architecture. The library
/// requires that all state mutations happen by sending an action so that a reducer can handle that
/// logic, which greatly simplifies how data flows through your application, and gives you instant
/// testability on all parts of your application.
///
/// To use this API, you model all the action sheet actions in your domain's action enum:
///
///     enum Action {
///       case cancelTapped
///       case deleteTapped
///       case favoriteTapped
///       case infoTapped
///
///       // Your other actions
///     }
///
/// And you model the state for showing the action sheet in your domain's state, and it can start
/// off in the `.dismissed` state:
///
///     struct AppState {
///       var actionSheet = ActionSheetState<AppAction>.dismissed
///       // Your other state
///     }
///
/// Then, in the reducer you can construct an `ActionSheetState` value to represent the action
/// sheet you want to show to the user:
///
///     let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
///       switch action
///         case .cancelTapped:
///           state.actionSheet = .dismissed
///           return .none
///
///         case .deleteTapped:
///           state.actionSheet = .dismissed
///           // Do deletion logic...
///
///         case .favoriteTapped:
///           state.actionSheet = .dismissed
///           // Do favoriting logic
///
///         case .infoTapped:
///           state.actionSheet = .show(
///             .init(
///               buttons: [
///                 .init(
///                   action: .favoriteTapped,
///                   label: "Favorite"
///                 ),
///                 .init(
///                   action: .deleteTapped,
///                   label: "Delete"
///                 ),
///                 .init(
///                   action: .cancelTapped,
///                   label: "Cancel",
///                   type: .cancel
///                 )
///               ],
///               title: "What would you like to do?"
///             )
///           )
///         return .none
///       }
///     }
///
/// And then, in your view you can use the `.actionSheet(_:send:dismiss:)` method on `View` in order
/// to present the action sheet in a way that works best with the Composable Architecture:
///
///     Button("Info") { viewStore.send(.infoTapped) }
///       .actionSheet(
///         viewStore.actionSheet,
///         send: viewStore.send,
///         dismiss: .cancelTapped
///       )
///
/// This makes your reducer in complete control of when the action sheet is shown or dismissed, and
/// makes it so that any choice made in the action sheet is automatically fed back into the reducer
/// so that you can handle its logic.
///
/// Even better, you can instantly write tests that your action sheet behavior works as expected:
///
///     let store = TestStore(
///       initialState: AppState(),
///       reducer: appReducer,
///       environment: .mock
///     )
///
///     store.assert(
///       .send(.infoTapped) {
///         $0.actionSheet = .show(
///           .init(
///             buttons: [
///               .init(
///                 action: .favoriteTapped,
///                 label: "Favorite"
///               ),
///               .init(
///                 action: .deleteTapped,
///                 label: "Delete"
///               ),
///               .init(
///                 action: .cancelTapped,
///                 label: "Cancel",
///                 type: .cancel
///               )
///             ],
///             title: "What would you like to do?"
///           )
///         )
///       },
///       .send(.favoriteTapped) {
///         $0.actionSheet = .dismissed
///         // Also verify that favoriting logic executed correctly
///       }
///     )
///
@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
public enum ActionSheetState<Action> {
  case dismissed
  case show(ActionSheet)

  public struct ActionSheet {
    public var buttons: [Button]
    public var message: String?
    public var title: String

    public init(
      buttons: [Button],
      message: String? = nil,
      title: String
    ) {
      self.buttons = buttons
      self.message = message
      self.title = title
    }

    public struct Button {
      public var action: Action
      public var label: String
      public var type: `Type`

      public init(
        action: Action,
        label: String,
        type: `Type` = .default
      ) {
        self.action = action
        self.label = label
        self.type = type
      }

      public enum `Type` {
        case cancel
        case `default`
        case destructive
      }
    }
  }
}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState: Equatable where Action: Equatable {}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState: Hashable where Action: Hashable {}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState.ActionSheet: Equatable where Action: Equatable {}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState.ActionSheet: Hashable where Action: Hashable {}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState.ActionSheet.Button: Equatable where Action: Equatable {}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState.ActionSheet.Button: Hashable where Action: Hashable {}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState.ActionSheet: Identifiable where Action: Hashable {
  public var id: Self { self }
}

extension View {
  /// Displays an action sheet when `state` is in the `.show` state.
  ///
  /// - Parameters:
  ///   - state: A value that describes if the action sheet is shown or dismissed.
  ///   - send: A reference to the view store's `send` method for which actions from this action
  ///   sheet should be sent to.
  ///   - dismissal: An action to send when the action sheet is dismissed through non-user actions,
  ///   such as when an action sheet is automatically dismissed by the system.
  @available(iOS 13, *)
  @available(macCatalyst 13, *)
  @available(macOS, unavailable)
  @available(tvOS 13, *)
  @available(watchOS 6, *)
  public func actionSheet<Action>(
    _ state: ActionSheetState<Action>,
    send: @escaping (Action) -> Void,
    dismissal: Action
  ) -> some View where Action: Hashable {

    self.actionSheet(
      item: Binding<ActionSheetState<Action>.ActionSheet?>(
        get: {
          switch state {
          case .dismissed:
            return nil
          case let .show(actionSheet):
            return actionSheet
          }
        },
        set: {
          guard $0 == nil else { return }
          send(dismissal)
        }),
      content: { $0.toSwiftUI(send: send) }
    )
  }
}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState.ActionSheet.Button {
  fileprivate func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.ActionSheet.Button {
    switch self.type {
    case .cancel:
      return .cancel(Text(self.label)) { send(self.action) }
    case .default:
      return .default(Text(self.label)) { send(self.action) }
    case .destructive:
      return .destructive(Text(self.label)) { send(self.action) }
    }
  }
}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState.ActionSheet {
  fileprivate func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.ActionSheet {

    SwiftUI.ActionSheet(
      title: Text(self.title),
      message: self.message.map { Text($0) },
      buttons: self.buttons.map {
        $0.toSwiftUI(send: send)
      }
    )
  }
}
