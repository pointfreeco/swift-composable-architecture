import SwiftUI

// TODO: does .task cancel its work when pushing away from a view? or just when popping?

// TODO: remove this and use PresentationAction
public enum NavigationAction<Action> {
  case isActive(Action)
  case setNavigation(isActive: Bool)
}

extension NavigationAction: Equatable where Action: Equatable {}
extension NavigationAction: Hashable where Action: Hashable {}

extension Reducer {
  public func navigates<Route, LocalState, LocalAction, LocalEnvironment>(
    _ localReducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
    tag: CasePath<Route, LocalState>,
    selection: WritableKeyPath<State, Route?>,
    action toNavigationAction: CasePath<Action, NavigationAction<LocalAction>>,
    environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
  ) -> Self {
    let id = UUID()
    return Self { state, action, environment in
      let wasPresented = state[keyPath: selection].flatMap(tag.extract(from:)) != nil
      var effects: [Effect<Action, Never>] = []

      effects.append(
        localReducer
          /*
           .pullback(
             state: selection.appending(path: tag),
             action: toNavigationAction.appending(path: /NavigationAction.isActive),
             environment: toLocalEnvironment
           )
           */
          .pullback(
            state: tag,
            action: /.self,
            environment: toLocalEnvironment
          )
          .optional()
          .pullback(
            state: selection,
            action: toNavigationAction.appending(path: /NavigationAction.isActive),
            environment: { $0 }
          )
          .run(&state, action, environment)
          .cancellable(id: id)
      )

      effects.append(
        self
          .run(&state, action, environment)
      )

      if state[keyPath: selection].flatMap(tag.extract(from:)) != nil,
         case .some(.setNavigation(isActive: false)) = toNavigationAction.extract(from: action)
      {
        state[keyPath: selection] = nil
      }
      if wasPresented && state[keyPath: selection] == nil {
        effects.append(.cancel(id: id))
      }

      return .merge(effects)
    }
  }

  public func navigates<Route, LocalState, LocalAction, LocalEnvironment>(
    _ localReducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
    tag: Route,
    selection: WritableKeyPath<State, Route?>,
    state toLocalState: WritableKeyPath<State, LocalState>,
    action toNavigationAction: CasePath<Action, NavigationAction<LocalAction>>,
    environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
  ) -> Self {
    let id = UUID()
    return Self { state, action, environment in
      let wasPresented = enumTag(state[keyPath: selection]) == enumTag(tag)
      var effects: [Effect<Action, Never>] = []

      effects.append(
        localReducer
          .pullback(
            state: toLocalState,
            action: toNavigationAction.appending(path: /NavigationAction.isActive),
            environment: toLocalEnvironment
          )
          .run(&state, action, environment)
          .cancellable(id: id)
      )

      effects.append(
        self.run(&state, action, environment)
      )

      switch toNavigationAction.extract(from: action) {
      case .some(.setNavigation(isActive: true))
        where state[keyPath: selection] == nil:
        state[keyPath: selection] = tag

      case .some(.setNavigation(isActive: false))
        where enumTag(state[keyPath: selection]) == enumTag(tag):
        state[keyPath: selection] = nil

      default:
        break
      }
      if wasPresented && state[keyPath: selection] == nil {
        effects.append(.cancel(id: id))
      }

      return .merge(effects)
    }
  }

  public func navigates<LocalState, LocalAction, LocalEnvironment>(
    _ localReducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
    state toLocalState: WritableKeyPath<State, LocalState?>,
    action toNavigationAction: CasePath<Action, NavigationAction<LocalAction>>,
    environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
  ) -> Self {
    self.navigates(
      localReducer,
      tag: /.self,
      selection: toLocalState,
      action: toNavigationAction,
      environment: toLocalEnvironment
    )
  }

  public func navigates<LocalState, LocalAction, LocalEnvironment>(
    _ localReducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
    isActive: WritableKeyPath<State, Bool>,
    state toLocalState: WritableKeyPath<State, LocalState>,
    action toNavigationAction: CasePath<Action, NavigationAction<LocalAction>>,
    environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
  ) -> Self {
    let id = UUID()
    return Self { state, action, environment in
      let wasPresented = state[keyPath: isActive]
      var effects: [Effect<Action, Never>] = []

      effects.append(
        localReducer
          .pullback(
            state: toLocalState,
            action: toNavigationAction.appending(path: /NavigationAction.isActive),
            environment: toLocalEnvironment
          )
          .run(&state, action, environment)
          .cancellable(id: id)
      )

      effects.append(
        self.run(&state, action, environment)
      )

      switch toNavigationAction.extract(from: action) {
      case .some(.setNavigation(isActive: true)) where !state[keyPath: isActive]:
        state[keyPath: isActive] = true

      case .some(.setNavigation(isActive: false)) where state[keyPath: isActive]:
        state[keyPath: isActive] = false

      default:
        break
      }
      if wasPresented && !state[keyPath: isActive] {
        effects.append(.cancel(id: id))
      }

      return .merge(effects)
    }
  }
}

public struct NavigationLinkStore<Route, State, Action, Label, Destination>: View
where
  Label: View,
  Destination: View
{
  let destination: Destination
  let label: () -> Label
  let selection: Store<Bool, NavigationAction<Action>>

  public init<Content>(
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Content,
    tag: @escaping (Route) -> State?,
    selection: Store<Route?, NavigationAction<Action>>,
    @ViewBuilder label: @escaping () -> Label
  ) where Destination == IfLetStore<State, Action, Content?> {
    self.destination = IfLetStore<State, Action, Content?>(
      selection.scope(
        state: { $0.flatMap(tag) },
        action: NavigationAction.isActive
      ),
      then: destination
    )
    self.label = label
    self.selection = selection.scope(state: { $0.flatMap(tag) != nil })
  }

  public init(
    @ViewBuilder destination: () -> Destination,
    tag: Route,
    selection: Store<Route?, NavigationAction<Action>>,
    @ViewBuilder label: @escaping () -> Label
  ) where State == Void {
    self.destination = destination()
    self.label = label
    self.selection = selection.scope(state: { enumTag($0) == enumTag(tag) })
  }

  public init(
    @ViewBuilder destination: () -> Destination,
    isActive: Store<Bool, NavigationAction<Action>>,
    @ViewBuilder label: @escaping () -> Label
  ) where Route == Bool, State == Void {
    self.destination = destination()
    self.label = label
    self.selection = isActive
  }

  public init<Content>(
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Content,
    ifLet selection: Store<State?, NavigationAction<Action>>,
    @ViewBuilder label: @escaping () -> Label
  ) where Route == State, Destination == IfLetStore<State, Action, Content?> {
    self.init(
      destination: destination,
      tag: { $0 },
      selection: selection,
      label: label
    )
  }

  public var body: some View {
    WithViewStore(self.selection) { viewStore in
      NavigationLink(
        destination: self.destination,
        isActive: viewStore
          .binding(send: NavigationAction.setNavigation(isActive:))
          .removeDuplicates(),
        label: self.label
      )
    }
  }
}

extension NavigationLinkStore where Label == Text {
  public init<Content>(
    title: Text,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Content,
    tag: @escaping (Route) -> State?,
    selection: Store<Route?, NavigationAction<Action>>
  ) where Destination == IfLetStore<State, Action, Content?> {
    self.init(
      destination: destination,
      tag: tag,
      selection: selection,
      label: { title }
    )
  }

  public init(
    title: Text,
    @ViewBuilder destination: () -> Destination,
    tag: Route,
    selection: Store<Route?, NavigationAction<Action>>
  ) where State == Void {
    self.init(
      destination: destination,
      tag: tag,
      selection: selection,
      label: { title }
    )
  }

  public init<Content>(
    title: Text,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Content,
    ifLet selection: Store<State?, NavigationAction<Action>>
  ) where Route == State, Destination == IfLetStore<State, Action, Content?> {
    self.init(
      destination: destination,
      ifLet: selection,
      label: { title }
    )
  }

  public init(
    title: Text,
    @ViewBuilder destination: () -> Destination,
    isActive: Store<Bool, NavigationAction<Action>>
  ) where Route == Bool, State == Void {
    self.destination = destination()
    self.label = { title }
    self.selection = isActive
  }
}

extension Binding {
  fileprivate func removeDuplicates() -> Binding where Value: Equatable {
    return .init(
      get: {
        self.wrappedValue
      },
      set: { newValue, transaction in
        guard newValue != self.wrappedValue else { return }
        if transaction.animation != nil {
          withTransaction(transaction) {
            self.wrappedValue = newValue
          }
        } else {
          self.wrappedValue = newValue
        }
      }
    )
  }
}
