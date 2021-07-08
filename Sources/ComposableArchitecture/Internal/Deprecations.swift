import CasePaths
import Combine
import SwiftUI

// NB: Deprecated after 0.17.0:

extension IfLetStore {
  @available(*, deprecated, message: "'else' now takes a view builder closure")
  public init<IfContent, ElseContent>(
    _ store: Store<State?, Action>,
    @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent,
    else elseContent: @escaping @autoclosure () -> ElseContent
  ) where Content == _ConditionalContent<IfContent, ElseContent> {
    self.init(store, then: ifContent, else: elseContent)
  }
}

// NB: Deprecated after 0.13.0:

@available(*, deprecated, renamed: "BindingAction")
public typealias FormAction = BindingAction

extension Reducer {
  @available(*, deprecated, renamed: "binding")
  public func form(action toFormAction: CasePath<Action, BindingAction<State>>) -> Self {
    self.binding(action: toFormAction.extract(from:))
  }
}

// NB: Deprecated after 0.10.0:

@available(iOS 13, *)
@available(macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS 13, *)
@available(watchOS 6, *)
extension ActionSheetState {
  @available(*, deprecated, message: "'title' and 'message' should be 'TextState'")
  @_disfavoredOverload
  public init(
    title: LocalizedStringKey,
    message: LocalizedStringKey? = nil,
    buttons: [Button]
  ) {
    self.init(
      title: .init(title),
      message: message.map { .init($0) },
      buttons: buttons
    )
  }
}

extension AlertState {
  @available(*, deprecated, message: "'title' and 'message' should be 'TextState'")
  @_disfavoredOverload
  public init(
    title: LocalizedStringKey,
    message: LocalizedStringKey? = nil,
    dismissButton: Button? = nil
  ) {
    self.init(
      title: .init(title),
      message: message.map { .init($0) },
      dismissButton: dismissButton
    )
  }

  @available(*, deprecated, message: "'title' and 'message' should be 'TextState'")
  @_disfavoredOverload
  public init(
    title: LocalizedStringKey,
    message: LocalizedStringKey? = nil,
    primaryButton: Button,
    secondaryButton: Button
  ) {
    self.init(
      title: .init(title),
      message: message.map { .init($0) },
      primaryButton: primaryButton,
      secondaryButton: secondaryButton
    )
  }
}

extension AlertState.Button {
  @available(*, deprecated, message: "'label' should be 'TextState'")
  @_disfavoredOverload
  public static func cancel(
    _ label: LocalizedStringKey,
    send action: Action? = nil
  ) -> Self {
    Self(action: action, type: .cancel(label: .init(label)))
  }

  @available(*, deprecated, message: "'label' should be 'TextState'")
  @_disfavoredOverload
  public static func `default`(
    _ label: LocalizedStringKey,
    send action: Action? = nil
  ) -> Self {
    Self(action: action, type: .default(label: .init(label)))
  }

  @available(*, deprecated, message: "'label' should be 'TextState'")
  @_disfavoredOverload
  public static func destructive(
    _ label: LocalizedStringKey,
    send action: Action? = nil
  ) -> Self {
    Self(action: action, type: .destructive(label: .init(label)))
  }
}

// NB: Deprecated after 0.9.0:

extension Store {
  @_disfavoredOverload
  @available(*, deprecated, renamed: "publisherScope(state:)")
  public func scope<P: Publisher, LocalState>(
    state toLocalState: @escaping (AnyPublisher<State, Never>) -> P
  ) -> AnyPublisher<Store<LocalState, Action>, Never>
  where P.Output == LocalState, P.Failure == Never {
    self.publisherScope(state: toLocalState)
  }

  @_disfavoredOverload
  @available(*, deprecated, renamed: "publisherScope(state:action:)")
  public func scope<P: Publisher, LocalState, LocalAction>(
    state toLocalState: @escaping (AnyPublisher<State, Never>) -> P,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> AnyPublisher<Store<LocalState, LocalAction>, Never>
  where P.Output == LocalState, P.Failure == Never {
    self.publisherScope(state: toLocalState, action: fromLocalAction)
  }
}

// NB: Deprecated after 0.6.0:

extension Reducer {
  @available(*, deprecated, renamed: "optional()")
  public var optional: Reducer<State?, Action, Environment> {
    self.optional()
  }
}
