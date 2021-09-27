import CustomDump
import SwiftUI

/// A data type that describes the state of an alert that can be shown to the user. The `Action`
/// generic is the type of actions that can be sent from tapping on a button in the alert.
///
/// This type can be used in your application's state in order to control the presentation or
/// dismissal of alerts. It is preferable to use this API instead of the default SwiftUI API
/// for alerts because SwiftUI uses 2-way bindings in order to control the showing and dismissal
/// of alerts, and that does not play nicely with the Composable Architecture. The library requires
/// that all state mutations happen by sending an action so that a reducer can handle that logic,
/// which greatly simplifies how data flows through your application, and gives you instant
/// testability on all parts of your application.
///
/// To use this API, you model all the alert actions in your domain's action enum:
///
/// ```swift
/// enum AppAction: Equatable {
///   case cancelTapped
///   case confirmTapped
///   case deleteTapped
///
///   // Your other actions
/// }
/// ```
///
/// And you model the state for showing the alert in your domain's state, and it can start off
/// `nil`:
///
/// ```swift
/// struct AppState: Equatable {
///   var alert: AlertState<AppAction>?
///
///   // Your other state
/// }
/// ```
///
/// Then, in the reducer you can construct an ``AlertState`` value to represent the alert you want
/// to show to the user:
///
/// ```swift
/// let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
///   switch action
///     case .cancelTapped:
///       state.alert = nil
///       return .none
///
///     case .confirmTapped:
///       state.alert = nil
///       // Do deletion logic...
///
///     case .deleteTapped:
///       state.alert = .init(
///         title: TextState("Delete"),
///         message: TextState("Are you sure you want to delete this? It cannot be undone."),
///         primaryButton: .default(TextState("Confirm"), action: .send(.confirmTapped)),
///         secondaryButton: .cancel(TextState("Cancel"))
///       )
///     return .none
///   }
/// }
/// ```
///
/// And then, in your view you can use the `.alert(_:send:dismiss:)` method on `View` in order
/// to present the alert in a way that works best with the Composable Architecture:
///
/// ```swift
/// Button("Delete") { viewStore.send(.deleteTapped) }
///   .alert(
///     self.store.scope(state: \.alert),
///     dismiss: .cancelTapped
///   )
/// ```
///
/// This makes your reducer in complete control of when the alert is shown or dismissed, and makes
/// it so that any choice made in the alert is automatically fed back into the reducer so that you
/// can handle its logic.
///
/// Even better, you can instantly write tests that your alert behavior works as expected:
///
/// ```swift
/// let store = TestStore(
///   initialState: AppState(),
///   reducer: appReducer,
///   environment: .mock
/// )
///
/// store.send(.deleteTapped) {
///   $0.alert = .init(
///     title: TextState("Delete"),
///     message: TextState("Are you sure you want to delete this? It cannot be undone."),
///     primaryButton: .default(TextState("Confirm"), action: .send(.confirmTapped)),
///     secondaryButton: .cancel(TextState("Cancel"))
///   )
/// }
/// store.send(.deleteTapped) {
///   $0.alert = nil
///   // Also verify that delete logic executed correctly
/// }
/// ```
///
public struct AlertState<Action> {
  public let id = UUID()
  public var buttons: [Button]
  public var message: TextState?
  public var title: TextState

  @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
  public init(
    title: TextState,
    message: TextState? = nil,
    buttons: [Button]
  ) {
    self.title = title
    self.message = message
    self.buttons = buttons
  }

  public init(
    title: TextState,
    message: TextState? = nil,
    dismissButton: Button? = nil
  ) {
    self.title = title
    self.message = message
    self.buttons = dismissButton.map { [$0] } ?? []
  }

  public init(
    title: TextState,
    message: TextState? = nil,
    primaryButton: Button,
    secondaryButton: Button
  ) {
    self.title = title
    self.message = message
    self.buttons = [primaryButton, secondaryButton]
  }

  public struct Button {
    public var action: ButtonAction?
    public var label: TextState
    public var role: ButtonRole?

    public static func cancel(
      _ label: TextState,
      action: ButtonAction? = nil
    ) -> Self {
      Self(action: action, label: label, role: .cancel)
    }

    public static func `default`(
      _ label: TextState,
      action: ButtonAction? = nil
    ) -> Self {
      Self(action: action, label: label, role: nil)
    }

    public static func destructive(
      _ label: TextState,
      action: ButtonAction? = nil
    ) -> Self {
      Self(action: action, label: label, role: .destructive)
    }
  }

  public struct ButtonAction {
    let type: ActionType

    public static func send(_ action: Action) -> Self {
      .init(type: .send(action))
    }

    public static func send(_ action: Action, animation: Animation?) -> Self {
      .init(type: .animatedSend(action, animation: animation))
    }

    enum ActionType {
      case send(Action)
      case animatedSend(Action, animation: Animation?)
    }
  }

  public enum ButtonRole {
    case cancel
    case destructive

    #if compiler(>=5.5) && canImport(_Concurrency)
      @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
      var toSwiftUI: SwiftUI.ButtonRole {
        switch self {
        case .cancel:
          return .cancel
        case .destructive:
          return .destructive
        }
      }
    #endif
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
      #if compiler(>=5.5) && canImport(_Concurrency)
        if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
          self.alert(
            (viewStore.state?.title).map { Text($0) } ?? Text(""),
            isPresented: viewStore.binding(send: dismiss).isPresent(),
            presenting: viewStore.state,
            actions: { $0.toSwiftUIActions(send: viewStore.send) },
            message: { $0.message.map { Text($0) } }
          )
        } else {
          self.alert(item: viewStore.binding(send: dismiss)) { state in
            state.toSwiftUIAlert(send: viewStore.send)
          }
        }
      #else
        self.alert(item: viewStore.binding(send: dismiss)) { state in
          state.toSwiftUIAlert(send: viewStore.send)
        }
      #endif
    }
  }
}

extension AlertState: CustomDumpReflectable {
  public var customDumpMirror: Mirror {
    Mirror(
      self,
      children: [
        "title": self.title,
        "message": self.message as Any,
        "buttons": self.buttons,
      ],
      displayStyle: .struct
    )
  }
}

extension AlertState.Button: CustomDumpReflectable {
  public var customDumpMirror: Mirror {
    Mirror(
      self,
      children: [
        self.role.map { "\($0)" } ?? "default": (
          self.label,
          action: self.action
        )
      ],
      displayStyle: .enum
    )
  }
}

extension AlertState.ButtonAction: CustomDumpReflectable {
  public var customDumpMirror: Mirror {
    switch self.type {
    case let .send(action):
      return Mirror(
        self,
        children: [
          "send": action
        ],
        displayStyle: .enum
      )
    case let .animatedSend(action, animation):
      return Mirror(
        self,
        children: [
          "send": (action, animation: animation)
        ],
        displayStyle: .enum
      )
    }
  }
}

extension AlertState: Equatable where Action: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.title == rhs.title
      && lhs.message == rhs.message
      && lhs.buttons == rhs.buttons
  }
}

extension AlertState: Hashable where Action: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.title)
    hasher.combine(self.message)
    hasher.combine(self.buttons)
  }
}

extension AlertState: Identifiable {}

extension AlertState.ButtonAction: Equatable where Action: Equatable {}
extension AlertState.ButtonAction.ActionType: Equatable where Action: Equatable {}
extension AlertState.ButtonRole: Equatable {}
extension AlertState.Button: Equatable where Action: Equatable {}

extension AlertState.ButtonAction: Hashable where Action: Hashable {}
extension AlertState.ButtonAction.ActionType: Hashable where Action: Hashable {
  func hash(into hasher: inout Hasher) {
    switch self {
    case let .send(action), let .animatedSend(action, animation: _):
      hasher.combine(action)
    }
  }
}
extension AlertState.ButtonRole: Hashable {}
extension AlertState.Button: Hashable where Action: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.action)
    hasher.combine(self.label)
    hasher.combine(self.role)
  }
}

extension AlertState.Button {
  public func toSwiftUIAction(send: @escaping (Action) -> Void) -> () -> Void {
    return {
      switch self.action?.type {
      case .none:
        return
      case let .some(.send(action)):
        send(action)
      case let .some(.animatedSend(action, animation: animation)):
        withAnimation(animation) { send(action) }
      }
    }
  }

  func toSwiftUIAlertButton(send: @escaping (Action) -> Void) -> SwiftUI.Alert.Button {
    let action = self.toSwiftUIAction(send: send)
    switch self.role {
    case .cancel:
      return .cancel(Text(label), action: action)
    case .destructive:
      return .destructive(Text(label), action: action)
    case .none:
      return .default(Text(label), action: action)
    }
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    func toSwiftUIButton(send: @escaping (Action) -> Void) -> some View {
      SwiftUI.Button(
        role: self.role?.toSwiftUI,
        action: self.toSwiftUIAction(send: send)
      ) {
        Text(self.label)
      }
    }
  #endif
}

extension AlertState {
  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @ViewBuilder
    fileprivate func toSwiftUIActions(send: @escaping (Action) -> Void) -> some View {
      ForEach(self.buttons.indices, id: \.self) {
        self.buttons[$0].toSwiftUIButton(send: send)
      }
    }
  #endif

  fileprivate func toSwiftUIAlert(send: @escaping (Action) -> Void) -> SwiftUI.Alert {
    if self.buttons.count == 2 {
      return SwiftUI.Alert(
        title: Text(self.title),
        message: self.message.map { Text($0) },
        primaryButton: self.buttons[0].toSwiftUIAlertButton(send: send),
        secondaryButton: self.buttons[1].toSwiftUIAlertButton(send: send)
      )
    } else {
      return SwiftUI.Alert(
        title: Text(self.title),
        message: self.message.map { Text($0) },
        dismissButton: self.buttons.first?.toSwiftUIAlertButton(send: send)
      )
    }
  }
}
