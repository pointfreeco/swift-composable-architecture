import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically presented a sheet that \
  depends on this data.
  """

struct LoadThenPresentState: Equatable {
  var optionalCounter: CounterState?
  var isActivityIndicatorVisible = false
}

enum LoadThenPresentAction {
  case loadButtonTapped
  case optionalCounter(PresentationAction<CounterState, CounterAction, Bool>)
  case setSheetIsPresentedDelayCompleted
}

struct LoadThenPresentEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let loadThenPresentReducer =
  counterReducer
  .presented(
    state: \.optionalCounter,
    action: /LoadThenPresentAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      LoadThenPresentState, LoadThenPresentAction, LoadThenPresentEnvironment
    > { state, action, environment in
      switch action {
      case .loadButtonTapped:
        state.isActivityIndicatorVisible = true
        return Effect(value: .setSheetIsPresentedDelayCompleted)
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()

      case .optionalCounter(.presented(.incrementButtonTapped)):
        return .none

      case .optionalCounter:
        return .none

      case .setSheetIsPresentedDelayCompleted:
        state.isActivityIndicatorVisible = false
        state.optionalCounter = CounterState()
        return .none
      }
    }
  )

struct LoadThenPresentView: View {
  let store: Store<LoadThenPresentState, LoadThenPresentAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          Button(action: { viewStore.send(.loadButtonTapped) }) {
            HStack {
              Text("Load optional counter")
              if viewStore.isActivityIndicatorVisible {
                Spacer()
                ActivityIndicator()
              }
            }
          }
        }
      }
      .sheet(
        store: self.store.scope(
          state: \.optionalCounter,
          action: LoadThenPresentAction.optionalCounter
        ),
        content: { CounterView(store: $0) }
      )
      .navigationBarTitle("Load and present")
    }
  }
}

struct LoadThenPresentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenPresentView(
        store: Store(
          initialState: LoadThenPresentState(),
          reducer: loadThenPresentReducer,
          environment: LoadThenPresentEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
  }
}

import CasePaths
extension Reducer {

  func cancellable(id: AnyHashable) -> Reducer {
    .init { state, action, environment in
      self.run(&state, action, environment).cancellable(id: id)
    }
  }

  func presented<GlobalState, GlobalAction, GlobalEnvironment>(
    state toLocalState: WritableKeyPath<GlobalState, State?>,
    action toSheetAction: CasePath<GlobalAction, PresentationAction<State, Action, Bool>>,
    environment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    let id = UUID()
    return self
      .optional()
      .pullback(
        state: toLocalState,
        action: toSheetAction .. /PresentationAction.presented,
        environment: environment
      )
      .cancellable(id: id)
      .combined(with: .init { state, action, environment in
        guard let sheetAction = toSheetAction.extract(from: action)
        else { return .none }

        switch sheetAction {
        case .presented(_):
          return .none
        case let .setPresentation(isPresented):
          if !isPresented {
            state[keyPath: toLocalState] = nil
          }
          return !isPresented
            ? .cancel(id: id)
            : .none
        }
      })
  }
  func presented<GlobalState, GlobalAction, GlobalEnvironment, Tag: Hashable>(
    state toLocalState: WritableKeyPath<GlobalState, State?>,
    action toSheetAction: CasePath<GlobalAction, PresentationAction<State, Action, Tag?>>,
    environment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    let id = UUID()
    return self
      .optional()
      .pullback(
        state: toLocalState,
        action: toSheetAction .. /PresentationAction.presented,
        environment: environment
      )
      .cancellable(id: id)
      .combined(with: .init { state, action, environment in
        guard let sheetAction = toSheetAction.extract(from: action)
        else { return .none }

        switch sheetAction {
        case .presented(_):
          return .none
        case let .setPresentation(tag):
          if tag == nil {
            state[keyPath: toLocalState] = nil
          }
          return tag == nil
            ? .cancel(id: id)
            : .none
        }
      })
  }
}

public enum PresentationAction<State, Action, Tag: Hashable> {
  case presented(Action)
  case setPresentation(Tag)
}

extension PresentationAction: Equatable where State: Equatable, Action: Equatable {}

import SwiftUI

extension View {
  public func sheet<State, Action, Content: View>(
    store: Store<State?, PresentationAction<State, Action, Bool>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    WithViewStore(store.scope(state: { $0 != nil })) { viewStore in
      self.sheet(
        isPresented: viewStore.binding(send: PresentationAction.setPresentation),
        content: {
          LastNonEmptyView(store.scope(state: { $0 }, action: PresentationAction.presented), then: content)
        }
      )
    }
  }
}

struct LastNonEmptyView<State, Action, Content>: View where Content: View {
  let content: (ViewStore<State?, Action>) -> Content
  let store: Store<State?, Action>

  public init<IfContent>(
    _ store: Store<State?, Action>,
    @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent
  ) where Content == _ConditionalContent<IfContent, EmptyView> {
    self.store = store
    var lastState: State?
    self.content = { viewStore in
      lastState = viewStore.state ?? lastState
      if let lastState = lastState {
        return ViewBuilder.buildEither(first: ifContent(store.scope(state: { $0 ?? lastState })))
      } else {
        return ViewBuilder.buildEither(second: EmptyView())
      }
    }
  }

  public var body: some View {
    WithViewStore(
      self.store,
      removeDuplicates: { ($0 != nil) == ($1 != nil) },
      content: self.content
    )
  }
}
