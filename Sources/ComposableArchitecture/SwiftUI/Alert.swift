import SwiftUI

/// A data type that describes the state of an alert that can be shown to the user. The `Action`
/// generic is the type of actions that can be sent from tapping on a button in the alert.
///
/// This type can be used in your application's state in order to control the presentation or
/// dismissal of alerts. It is preferrable to use this API instead of the default SwiftUI API
/// for alerts because SwiftUI uses 2-way bindings in order to control the showing and dismissal
/// of alerts, and that does not play nicely with the Composable Architecture. The library requires
/// that all state mutations happen by sending an action so that a reducer can handle that logic,
/// which greatly simplifies how data flows through your application, and gives you instant
/// testability on all parts of your application.
///
/// To use this API, you model all the alert actions in your domain's action enum:
///
///     enum Action {
///       case cancelTapped
///       case confirmTapped
///       case deleteTapped
///
///       // Your other actions
///     }
///
/// And you model the state for showing the alert in your domain's state, and it can start off in
/// the `.dismissed` state:
///
///     struct AppState {
///       var alert = AlertState<AppAction>.dismissed
///       // Your other state
///     }
///
/// Then, in the reducer you can construct an `AlertState` value to represent the alert you want
/// to show to the user:
///
///     let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
///       switch action
///         case .cancelTapped:
///           state.alert = .dismissed
///           return .none
///
///         case .confirmTapped:
///           state.alert = .dismissed
///           // Do deletion logic...
///
///         case .deleteTapped:
///           state.alert = .show(
///             .init(
///               message: "Are you sure you want to delete this? It cannot be undone.",
///               primaryButton: .init(
///                 action: .confirmTapped,
///                 label: "Confirm"
///               ),
///               secondaryButton: .init(
///                 action: .cancelTapped,
///                 label: "Cancel",
///                 type: .cancel
///               ),
///               title: "Delete"
///             )
///           )
///         return .none
///       }
///     }
///
/// And then, in your view you can use the `.alert(_:send:dismiss:)` method on `View` in order
/// to present the alert in a way that works best with the Composable Architecture:
///
///     Button("Delete") { viewStore.send(.deleteTapped) }
///       .alert(
///         viewStore.alert,
///         send: viewStore.send,
///         dismiss: .cancelTapped
///       )
///
/// This makes your reducer in complete control of when the alert is shown or dismissed, and makes
/// it so that any choice made in the alert is automatically fed back into the reducer so that you
/// can handle its logic.
///
/// Even better, you can instantly write tests that your alert behavior works as expected:
///
///     let store = TestStore(
///       initialState: AppState(),
///       reducer: appReducer,
///       environment: .mock
///     )
///
///     store.assert(
///       .send(.deleteTapped) {
///         $0.alert = .show(
///           .init(
///             message: "Are you sure you want to delete this? It cannot be undone.",
///             primaryButton: .init(
///               action: .confirmTapped,
///               label: "Confirm"
///             ),
///             secondaryButton: .init(
///               action: .cancelTapped,
///               label: "Cancel",
///               type: .cancel
///             ),
///             title: "Delete"
///           )
///         )
///       },
///       .send(.deleteTapped) {
///         $0.alert = .dismissed
///         // Also verify that delete logic executed correctly
///       }
///     )
///
public enum AlertState<Action> {
  case dismissed
  case show(Alert)

  public struct Alert {
    public var message: String?
    public var primaryButton: Button
    public var secondaryButton: Button?
    public var title: String

    public init(
      message: String? = nil,
      primaryButton: Button,
      secondaryButton: Button? = nil,
      title: String
    ) {
      self.message = message
      self.primaryButton = primaryButton
      self.secondaryButton = secondaryButton
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

extension View {
  /// Displays an alert when `state` is in the `.show` state.
  ///
  /// - Parameters:
  ///   - state: A value that describes if the alert is shown or dismissed.
  ///   - send: A reference to the view store's `send` method for which actions from this alert
  ///   should be sent to.
  ///   - dismissal: An action to send when the alert is dismissed through non-user actions, such
  ///   as when an alert is automatically dismissed by the system.
  public func alert<Action>(
    _ state: AlertState<Action>,
    send: @escaping (Action) -> Void,
    dismissal: Action
  ) -> some View where Action: Hashable {

    self.alert(
      item: Binding<AlertState<Action>.Alert?>(
        get: {
          switch state {
          case .dismissed:
            return nil
          case let .show(alert):
            return alert
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

extension AlertState: Equatable where Action: Equatable {}
extension AlertState: Hashable where Action: Hashable {}
extension AlertState.Alert: Equatable where Action: Equatable {}
extension AlertState.Alert: Hashable where Action: Hashable {}
extension AlertState.Alert.Button: Equatable where Action: Equatable {}
extension AlertState.Alert.Button: Hashable where Action: Hashable {}

extension AlertState.Alert: Identifiable where Action: Hashable {
  public var id: Self { self }
}

extension AlertState.Alert.Button {
  fileprivate func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.Alert.Button {
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

extension AlertState.Alert {
  fileprivate func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.Alert {
    let title = Text(self.title)
    let message = self.message.map { Text($0) }

    if let secondaryButton = self.secondaryButton {
      return SwiftUI.Alert(
        title: title,
        message: message,
        primaryButton: self.primaryButton.toSwiftUI(send: send),
        secondaryButton: secondaryButton.toSwiftUI(send: send)
      )
    } else {
      return SwiftUI.Alert(
        title: title,
        message: message,
        dismissButton: self.primaryButton.toSwiftUI(send: send)
      )
    }
  }
}
