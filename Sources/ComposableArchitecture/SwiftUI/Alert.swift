import SwiftUI

/// A data type that describes the state of an alert that can be shown to the user.
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
        type: `Type`
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

extension AlertState: Equatable where Action: Equatable {}
extension AlertState: Hashable where Action: Hashable {}
extension AlertState.Alert: Equatable where Action: Equatable {}
extension AlertState.Alert: Hashable where Action: Hashable {}
extension AlertState.Alert.Button: Equatable where Action: Equatable {}
extension AlertState.Alert.Button: Hashable where Action: Hashable {}

extension AlertState.Alert: Identifiable where Action: Hashable {
  public var id: Self { self }
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

extension AlertState.Alert.Button {
  fileprivate func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.Alert.Button {
    switch self.type {
    case .cancel:
      return SwiftUI.Alert.Button.cancel(Text(self.label)) { send(self.action) }
    case .default:
      return SwiftUI.Alert.Button.default(Text(self.label)) { send(self.action) }
    case .destructive:
      return SwiftUI.Alert.Button.destructive(Text(self.label)) { send(self.action) }
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
