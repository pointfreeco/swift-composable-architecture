import Combine
import SwiftUI

// NB: Deprecated after 0.13.0:

@available(*, deprecated, renamed: "BindingAction")
public typealias FormAction = BindingAction

extension Reducer {
  @available(*, deprecated, renamed: "binding")
  public func form(action toFormAction: CasePath<Action, BindingAction<State>>) -> Self {
    self.binding(action: toFormAction)
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
  @available(*, deprecated, renamed: "publisherScope(state:)")
  public func scope<P: Publisher, LocalState>(
    state toLocalState: @escaping (AnyPublisher<State, Never>) -> P
  ) -> AnyPublisher<Store<LocalState, Action>, Never>
  where P.Output == LocalState, P.Failure == Never {
    self.publisherScope(state: toLocalState)
  }

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

// NB: Deprecated after 0.1.4:

extension Reducer {
  @available(*, unavailable, renamed: "debug(_:environment:)")
  public func debug(
    prefix: String,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: { $0 }, action: .self, environment: toDebugEnvironment)
  }

  @available(*, unavailable, renamed: "debugActions(_:environment:)")
  public func debugActions(
    prefix: String,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: { _ in () }, action: .self, environment: toDebugEnvironment)
  }

  @available(*, unavailable, renamed: "debug(_:state:action:environment:)")
  public func debug<LocalState, LocalAction>(
    prefix: String,
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: CasePath<Action, LocalAction>,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Reducer {
    self.debug(prefix, state: toLocalState, action: toLocalAction, environment: toDebugEnvironment)
  }
}

extension WithViewStore {
  @available(*, unavailable, renamed: "debug(_:)")
  public func debug(prefix: String) -> Self {
    self.debug(prefix)
  }
}

// NB: Deprecated after 0.1.3:

extension Effect {
  @available(*, unavailable, renamed: "run")
  public static func async(
    _ work: @escaping (Effect.Subscriber) -> Cancellable
  ) -> Self {
    self.run(work)
  }
}

extension Effect where Failure == Swift.Error {
  @available(*, unavailable, renamed: "catching")
  public static func sync(_ work: @escaping () throws -> Output) -> Self {
    self.catching(work)
  }
}
