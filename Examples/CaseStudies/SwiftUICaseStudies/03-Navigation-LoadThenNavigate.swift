import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically navigated to the screen \
  that depends on this data.
  """

struct LoadThenNavigateState: Equatable {
  var optionalCounter: CounterState?
  var isActivityIndicatorVisible = false
}

enum LoadThenNavigateAction {
  case optionalCounter(PresentationAction<CounterState, CounterAction, Bool>)
  case setNavigationIsActiveDelayCompleted
}

struct LoadThenNavigateEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let loadThenNavigateReducer =
  counterReducer
  .presented(
    state: \.optionalCounter,
    action: /LoadThenNavigateAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      LoadThenNavigateState, LoadThenNavigateAction, LoadThenNavigateEnvironment
    > { state, action, environment in
      switch action {
      case .optionalCounter(.setPresentation(true)):
        state.isActivityIndicatorVisible = true
        return Effect(value: .setNavigationIsActiveDelayCompleted)
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()

      case .optionalCounter:
        return .none

      case .setNavigationIsActiveDelayCompleted:
        state.isActivityIndicatorVisible = false
        state.optionalCounter = CounterState()
        return .none
      }
    }
  )

struct NavigationLinkStore<State, Action, Label: View, Destination: View, Tag: Hashable>: View {
  let store: Store<State?, PresentationAction<State, Action, Tag?>>
  let destination: (Store<State, Action>) -> Destination
  let tag: Tag
  let currentTag: (State) -> Tag?
  let label: () -> Label

  init(
    store: Store<State?, PresentationAction<State, Action, Tag?>>,
    tag: Tag,
    currentTag: @escaping (State) -> Tag?,
    destination: @escaping (Store<State, Action>) -> Destination,
    @ViewBuilder label: @escaping () -> Label
  ) {
    self.store = store
    self.tag = tag
    self.currentTag = currentTag
    self.destination = destination
    self.label = label
  }

  var body: some View {
    WithViewStore(self.store.scope(state: { $0.flatMap(currentTag) })) { viewStore in
      NavigationLink(//destination: <#T##_#>, tag: <#T##Hashable#>, selection: <#T##Binding<Hashable?>#>, label: <#T##() -> _#>
        destination: LastNonEmptyView(
          self.store.scope(state: { $0 }, action: PresentationAction.presented),
          then: destination
        ),
        tag: self.tag,
        selection: viewStore.binding(send: PresentationAction.setPresentation),
        label: label
      )
    }
  }
}


struct LoadThenNavigateView: View {
  let store: Store<LoadThenNavigateState, LoadThenNavigateAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          NavigationLinkStore(
            store: self.store.scope(state: \.optionalCounter, action: LoadThenNavigateAction.optionalCounter),
            destination: { CounterView(store: $0) },
            label: {
              HStack {
                Text("Load optional counter")
                if viewStore.isActivityIndicatorVisible {
                  Spacer()
                  ActivityIndicator()
                }
              }
            }
          )
//          NavigationLink(
//            destination: IfLetStore(
//              self.store.scope(
//                state: { $0.optionalCounter }, action: LoadThenNavigateAction.optionalCounter),
//              then: { CounterView(store: $0) }
//            ),
//            isActive: viewStore.binding(
//              get: { $0.isNavigationActive },
//              send: LoadThenNavigateAction.setNavigation(isActive:)
//            )
//          ) {
//            HStack {
//              Text("Load optional counter")
//              if viewStore.isActivityIndicatorVisible {
//                Spacer()
//                ActivityIndicator()
//              }
//            }
//          }
        }
      }
    }
    .navigationBarTitle("Load then navigate")
  }
}

struct LoadThenNavigateView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenNavigateView(
        store: Store(
          initialState: LoadThenNavigateState(),
          reducer: loadThenNavigateReducer,
          environment: LoadThenNavigateEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}
