import SwiftUI

// TODO: does .task cancel its work when pushing away from a view? or just when popping?

extension Reducer {
  public func navigates<Route, DestinationState, DestinationAction, DestinationEnvironment>(
    destination: Reducer<DestinationState, DestinationAction, DestinationEnvironment>,
    tag: CasePath<Route, DestinationState>,
    selection: WritableKeyPath<State, Route?>,
    onDismiss: DestinationAction? = nil,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    environment toDestinationEnvironment: @escaping (Environment) -> DestinationEnvironment
  ) -> Self {
    Self { state, action, environment in
      let previousSelection = state[keyPath: selection]
      let previousTag = previousSelection.flatMap(tag.extract(from:)) != nil
        ? previousSelection.flatMap(enumTag)
        : nil
      var effects: [Effect<Action, Never>] = []

      effects.append(
        destination
          .pullback(
            state: tag,
            action: /.self,
            environment: toDestinationEnvironment
          )
          .optional()
          .pullback(
            state: selection,
            action: toPresentationAction.appending(path: /PresentationAction.presented),
            environment: { $0 }
          )
          .run(&state, action, environment)
      )
      let updatedDestinationState = state[keyPath: selection].flatMap(tag.extract(from:))

      effects.append(
        self
          .run(&state, action, environment)
      )

      if
        let route = state[keyPath: selection],
        tag.extract(from: route) != nil,
        case .some(.dismiss) = toPresentationAction.extract(from: action)
      {
        state[keyPath: selection] = nil
      }
      if
        let onDismiss = onDismiss,
        var finalDestinationState = updatedDestinationState,
        let previousTag = previousTag,
        previousTag != state[keyPath: selection].flatMap(enumTag)
      {
        effects.append(
          destination.run(
            &finalDestinationState,
            onDismiss,
            toDestinationEnvironment(environment)
          )
            .map(toPresentationAction.appending(path: /PresentationAction.presented).embed(_:))
        )
      }

      return .merge(effects)
    }
  }

  public func navigates<Route, DestinationState, DestinationAction, DestinationEnvironment>(
    destination: Reducer<DestinationState, DestinationAction, DestinationEnvironment>,
    tag: Route,
    selection: WritableKeyPath<State, Route?>,
    onDismiss: DestinationAction? = nil,
    state toDestinationState: WritableKeyPath<State, DestinationState>,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    environment toDestinationEnvironment: @escaping (Environment) -> DestinationEnvironment
  ) -> Self {
    let destinationTag = enumTag(tag)
    return Self { state, action, environment in
      let wasPresented = enumTag(state[keyPath: selection]) == destinationTag
      var effects: [Effect<Action, Never>] = []

      effects.append(
        destination
          .pullback(
            state: toDestinationState,
            action: toPresentationAction.appending(path: /PresentationAction.presented),
            environment: toDestinationEnvironment
          )
          .run(&state, action, environment)
      )

      effects.append(
        self.run(&state, action, environment)
      )

      switch toPresentationAction.extract(from: action) {
      case .some(.present)
        where state[keyPath: selection] == nil:
        state[keyPath: selection] = tag

      case .some(.dismiss)
        where enumTag(state[keyPath: selection]) == enumTag(tag):
        state[keyPath: selection] = nil

      default:
        break
      }
      if
        let onDismiss = onDismiss,
        wasPresented,
        enumTag(state[keyPath: selection]) != destinationTag
      {
        effects.append(
          destination.run(
            &state[keyPath: toDestinationState],
            onDismiss,
            toDestinationEnvironment(environment)
          )
            .map(toPresentationAction.appending(path: /PresentationAction.presented).embed(_:))
        )
      }

      return .merge(effects)
    }
  }

  public func navigates<DestinationState, DestinationAction, DestinationEnvironment>(
    destination: Reducer<DestinationState, DestinationAction, DestinationEnvironment>,
    onDismiss: DestinationAction? = nil,
    state toDestinationState: WritableKeyPath<State, DestinationState?>,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    environment toDestinationEnvironment: @escaping (Environment) -> DestinationEnvironment
  ) -> Self {
    self.navigates(
      destination: destination,
      tag: /.self,
      selection: toDestinationState,
      onDismiss: onDismiss,
      action: toPresentationAction,
      environment: toDestinationEnvironment
    )
  }

  public func navigates<DestinationState, DestinationAction, DestinationEnvironment>(
    destination: Reducer<DestinationState, DestinationAction, DestinationEnvironment>,
    isActive: WritableKeyPath<State, Bool>,
    onDismiss: DestinationAction? = nil,
    state toDestinationState: WritableKeyPath<State, DestinationState>,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    environment toDestinationEnvironment: @escaping (Environment) -> DestinationEnvironment
  ) -> Self {
    return Self { state, action, environment in
      let wasPresented = state[keyPath: isActive]
      var effects: [Effect<Action, Never>] = []

      effects.append(
        destination
          .pullback(
            state: toDestinationState,
            action: toPresentationAction.appending(path: /PresentationAction.presented),
            environment: toDestinationEnvironment
          )
          .run(&state, action, environment)
      )

      effects.append(
        self.run(&state, action, environment)
      )

      switch toPresentationAction.extract(from: action) {
      case .some(.present) where !state[keyPath: isActive]:
        state[keyPath: isActive] = true

      case .some(.dismiss) where state[keyPath: isActive]:
        state[keyPath: isActive] = false

      default:
        break
      }
      if let onDismiss = onDismiss, wasPresented, !state[keyPath: isActive] {
        effects.append(
          destination.run(
            &state[keyPath: toDestinationState],
            onDismiss,
            toDestinationEnvironment(environment)
          )
            .map(toPresentationAction.appending(path: /PresentationAction.presented).embed(_:))
        )
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
  let selection: Store<Bool, PresentationAction<Action>>

  public init<Content>(
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Content,
    tag: @escaping (Route) -> State?,
    selection: Store<Route?, PresentationAction<Action>>,
    @ViewBuilder label: @escaping () -> Label
  ) where Destination == IfLetStore<State, Action, Content?> {
    self.destination = IfLetStore<State, Action, Content?>(
      selection.scope(
        state: { $0.flatMap(tag) },
        action: PresentationAction.presented
      ),
      then: destination
    )
    self.label = label
    self.selection = selection.scope(state: { $0.flatMap(tag) != nil })
  }

  public init(
    @ViewBuilder destination: () -> Destination,
    tag: Route,
    selection: Store<Route?, PresentationAction<Action>>,
    @ViewBuilder label: @escaping () -> Label
  ) where State == Void {
    self.destination = destination()
    self.label = label
    self.selection = selection.scope(state: { enumTag($0) == enumTag(tag) })
  }

  public init(
    @ViewBuilder destination: () -> Destination,
    isActive: Store<Bool, PresentationAction<Action>>,
    @ViewBuilder label: @escaping () -> Label
  ) where Route == Bool, State == Void {
    self.destination = destination()
    self.label = label
    self.selection = isActive
  }

  public init<Content>(
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Content,
    ifLet selection: Store<State?, PresentationAction<Action>>,
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
          .binding(send: { $0 ? .present : .dismiss })
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
    selection: Store<Route?, PresentationAction<Action>>
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
    selection: Store<Route?, PresentationAction<Action>>
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
    ifLet selection: Store<State?, PresentationAction<Action>>
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
    isActive: Store<Bool, PresentationAction<Action>>
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
