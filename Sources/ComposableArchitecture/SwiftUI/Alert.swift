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
///     enum AppAction: Equatable {
///       case cancelTapped
///       case confirmTapped
///       case deleteTapped
///
///       // Your other actions
///     }
///
/// And you model the state for showing the alert in your domain's state, and it can start off
/// `nil`:
///
///     struct AppState: Equatable {
///       var alert = AlertState<AppAction>?
///
///       // Your other state
///     }
///
/// Then, in the reducer you can construct an `AlertState` value to represent the alert you want
/// to show to the user:
///
///     let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
///       switch action
///         case .cancelTapped:
///           state.alert = nil
///           return .none
///
///         case .confirmTapped:
///           state.alert = nil
///           // Do deletion logic...
///
///         case .deleteTapped:
///           state.alert = .init(
///             title: "Delete",
///             message: "Are you sure you want to delete this? It cannot be undone.",
///             primaryButton: .default("Confirm", send: .confirmTapped),
///             secondaryButton: .cancel()
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
///         self.store.scope(state: \.alert),
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
///         $0.alert = .init(
///           title: "Delete",
///           message: "Are you sure you want to delete this? It cannot be undone.",
///           primaryButton: .default("Confirm", send: .confirmTapped),
///           secondaryButton: .cancel(send: .cancelTapped)
///         )
///       },
///       .send(.deleteTapped) {
///         $0.alert = nil
///         // Also verify that delete logic executed correctly
///       }
///     )
///
public struct AlertState<Action> {
  public let id = UUID()
  public var message: String?
  public var primaryButton: Button?
  public var secondaryButton: Button?
  public var title: String

  public init(
    title: String,
    message: String? = nil,
    dismissButton: Button? = nil
  ) {
    self.title = title
    self.message = message
    self.primaryButton = dismissButton
  }

  public init(
    title: String,
    message: String? = nil,
    primaryButton: Button,
    secondaryButton: Button
  ) {
    self.title = title
    self.message = message
    self.primaryButton = primaryButton
    self.secondaryButton = secondaryButton
  }

  public struct Button {
    public var action: Action?
    public var type: `Type`

    public static func cancel(
      _ label: String,
      send action: Action? = nil
    ) -> Self {
      Self(action: action, type: .cancel(label: label))
    }

    public static func cancel(
      send action: Action? = nil
    ) -> Self {
      Self(action: action, type: .cancel(label: nil))
    }

    public static func `default`(
      _ label: String,
      send action: Action? = nil
    ) -> Self {
      Self(action: action, type: .default(label: label))
    }

    public static func destructive(
      _ label: String,
      send action: Action? = nil
    ) -> Self {
      Self(action: action, type: .destructive(label: label))
    }

    public enum `Type`: Hashable {
      case cancel(label: String?)
      case `default`(label: String)
      case destructive(label: String)
    }
  }
}

extension View {
  /// Displays an alert when then store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that describes if the alert is shown or dismissed.
  ///   - dismissal: An action to send when the alert is dismissed through non-user actions, such
  ///     as when an alert is automatically dismissed by the system. Use this action to `nil` out
  ///     the associated alert state.
  public func alert<Action>(
    _ store: Store<AlertState<Action>?, Action>,
    dismiss: Action
  ) -> some View {

    WithViewStore(store, removeDuplicates: { $0?.id == $1?.id }) { viewStore in
      self.alert(item: viewStore.binding(send: dismiss)) { state in
        state.toSwiftUI(send: viewStore.send)
      }
    }
  }
}

extension AlertState: CustomDebugOutputConvertible {
  public var debugOutput: String {
    let fields = (
      title: self.title,
      message: self.message,
      primaryButton: self.primaryButton,
      secondaryButton: self.secondaryButton
    )
    return "\(Self.self)\(ComposableArchitecture.debugOutput(fields))"
  }
}

extension AlertState: Equatable where Action: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.title == rhs.title
      && lhs.message == rhs.message
      && lhs.primaryButton == rhs.primaryButton
      && lhs.secondaryButton == rhs.secondaryButton
  }
}
extension AlertState: Hashable where Action: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.title)
    hasher.combine(self.message)
    hasher.combine(self.primaryButton)
    hasher.combine(self.secondaryButton)
  }
}
extension AlertState: Identifiable {}

extension AlertState.Button: Equatable where Action: Equatable {}
extension AlertState.Button: Hashable where Action: Hashable {}

extension AlertState.Button {
  func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.Alert.Button {
    let action = { if let action = self.action { send(action) } }
    switch self.type {
    case let .cancel(.some(label)):
      return .cancel(Text(label), action: action)
    case .cancel(.none):
      return .cancel(action)
    case let .default(label):
      return .default(Text(label), action: action)
    case let .destructive(label):
      return .destructive(Text(label), action: action)
    }
  }
}

extension AlertState {
  fileprivate func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.Alert {
    let title = Text(self.title)
    let message = self.message.map { Text($0) }

    if let primaryButton = self.primaryButton, let secondaryButton = self.secondaryButton {
      return SwiftUI.Alert(
        title: title,
        message: message,
        primaryButton: primaryButton.toSwiftUI(send: send),
        secondaryButton: secondaryButton.toSwiftUI(send: send)
      )
    } else {
      return SwiftUI.Alert(
        title: title,
        message: message,
        dismissButton: self.primaryButton?.toSwiftUI(send: send)
      )
    }
  }
}
