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
///     enum AppAction: Equatable {
///       case cancelTapped
///       case deleteTapped
///       case favoriteTapped
///       case infoTapped
///
///       // Your other actions
///     }
///
/// And you model the state for showing the action sheet in your domain's state, and it can start
/// off in a `nil` state:
///
///     struct AppState: Equatable {
///       var actionSheet: ActionSheetState<AppAction>?
///
///       // Your other state
///     }
///
/// Then, in the reducer you can construct an `ActionSheetState` value to represent the action
/// sheet you want to show to the user:
///
///     let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
///       switch action
///         case .cancelTapped:
///           state.actionSheet = nil
///           return .none
///
///         case .deleteTapped:
///           state.actionSheet = nil
///           // Do deletion logic...
///
///         case .favoriteTapped:
///           state.actionSheet = nil
///           // Do favoriting logic
///
///         case .infoTapped:
///           state.actionSheet = .init(
///             title: "What would you like to do?",
///             buttons: [
///               .default("Favorite", send: .favoriteTapped),
///               .destructive("Delete", send: .deleteTapped),
///               .cancel(),
///             ]
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
///         self.store.scope(state: \.actionSheet),
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
///         $0.actionSheet = .init(
///           title: "What would you like to do?",
///           buttons: [
///             .default("Favorite", send: .favoriteTapped),
///             .destructive("Delete", send: .deleteTapped),
///             .cancel(),
///           ]
///         )
///       },
///       .send(.favoriteTapped) {
///         $0.actionSheet = nil
///         // Also verify that favoriting logic executed correctly
///       }
///     )
///
@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
public struct ActionSheetState<Action> {
  public var buttons: [Button]
  public var message: String?
  public var title: String

  public init(
    title: String,
    message: String? = nil,
    buttons: [Button]
  ) {
    self.buttons = buttons
    self.message = message
    self.title = title
  }

  public typealias Button = AlertState<Action>.Button
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
extension ActionSheetState: Identifiable where Action: Hashable {
  public var id: Self { self }
}

extension View {
  /// Displays an action sheet when the store's state becomes non-`nil`, and dismisses it when it
  /// becomes `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that describes if the action sheet is shown or dismissed.
  ///   - dismissal: An action to send when the action sheet is dismissed through non-user actions,
  ///     such as when an action sheet is automatically dismissed by the system.
  @available(iOS 13, *)
  @available(macCatalyst 13, *)
  @available(macOS, unavailable)
  @available(tvOS 13, *)
  @available(watchOS 6, *)
  public func actionSheet<Action>(
    _ store: Store<ActionSheetState<Action>?, Action>,
    dismiss: Action
  ) -> some View {

    let viewStore = ViewStore(store, removeDuplicates: { ($0 == nil) != ($1 == nil) })
    return self.actionSheet(
      isPresented: Binding(
        get: { viewStore.state != nil },
        set: {
          guard !$0 else { return }
          viewStore.send(dismiss)
        }),
      content: { viewStore.state?.toSwiftUI(send: viewStore.send) ?? ActionSheet(title: Text("")) }
    )
  }
}

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState {
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
