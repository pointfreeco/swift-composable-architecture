import Combine
import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: Store<RootState, RootAction>

  var body: some View {
    WithViewStore(self.store.stateless) { viewStore in
      NavigationView {
        Form {
          Section(header: Text("Getting started")) {
            NavigationLink(
              "Basics",
              destination: CounterDemoView(
                store: self.store.scope(
                  state: \.counter,
                  action: RootAction.counter
                )
              )
            )

            NavigationLink(
              "Pullback and combine",
              destination: TwoCountersView(
                store: self.store.scope(
                  state: \.twoCounters,
                  action: RootAction.twoCounters
                )
              )
            )

            NavigationLink(
              "Bindings",
              destination: BindingBasicsView(
                store: self.store.scope(
                  state: \.bindingBasics,
                  action: RootAction.bindingBasics
                )
              )
            )

            NavigationLink(
              "Form bindings",
              destination: BindingFormView(
                store: self.store.scope(
                  state: \.bindingForm,
                  action: RootAction.bindingForm
                )
              )
            )

            NavigationLink(
              "Optional state",
              destination: OptionalBasicsView(
                store: self.store.scope(
                  state: \.optionalBasics,
                  action: RootAction.optionalBasics
                )
              )
            )

            NavigationLink(
              "Shared state",
              destination: SharedStateView(
                store: self.store.scope(
                  state: \.shared,
                  action: RootAction.shared
                )
              )
            )

            NavigationLink(
              "Alerts and Action Sheets",
              destination: AlertAndSheetView(
                store: self.store.scope(
                  state: \.alertAndActionSheet,
                  action: RootAction.alertAndActionSheet
                )
              )
            )

            NavigationLink(
              "Animations",
              destination: AnimationsView(
                store: self.store.scope(
                  state: \.animation,
                  action: RootAction.animation
                )
              )
            )
          }

          Section(header: Text("Effects")) {
            NavigationLink(
              "Basics",
              destination: EffectsBasicsView(
                store: self.store.scope(
                  state: \.effectsBasics,
                  action: RootAction.effectsBasics
                )
              )
            )

            NavigationLink(
              "Cancellation",
              destination: EffectsCancellationView(
                store: self.store.scope(
                  state: \.effectsCancellation,
                  action: RootAction.effectsCancellation)
              )
            )

            NavigationLink(
              "Long-living effects",
              destination: LongLivingEffectsView(
                store: self.store.scope(
                  state: \.longLivingEffects,
                  action: RootAction.longLivingEffects
                )
              )
            )

            #if compiler(>=5.5)
              NavigationLink(
                "Refreshable",
                destination: RefreshableView(
                  store: self.store.scope(
                    state: \.refreshable,
                    action: RootAction.refreshable
                  )
                )
              )
            #endif

            NavigationLink(
              "Timers",
              destination: TimersView(
                store: self.store.scope(
                  state: \.timers,
                  action: RootAction.timers
                )
              )
            )

            NavigationLink(
              "System environment",
              destination: MultipleDependenciesView(
                store: self.store.scope(
                  state: \.multipleDependencies,
                  action: RootAction.multipleDependencies
                )
              )
            )

            NavigationLink(
              "Web socket",
              destination: WebSocketView(
                store: self.store.scope(
                  state: \.webSocket,
                  action: RootAction.webSocket
                )
              )
            )
          }

          Section(header: Text("Navigation")) {
            NavigationLink(
              "Navigate and load data",
              destination: NavigateAndLoadView(
                store: self.store.scope(
                  state: \.navigateAndLoad,
                  action: RootAction.navigateAndLoad
                )
              )
            )

            NavigationLink(
              "Load data then navigate",
              destination: LoadThenNavigateView(
                store: self.store.scope(
                  state: \.loadThenNavigate,
                  action: RootAction.loadThenNavigate
                )
              )
            )

            NavigationLink(
              "Lists: Navigate and load data",
              destination: NavigateAndLoadListView(
                store: self.store.scope(
                  state: \.navigateAndLoadList,
                  action: RootAction.navigateAndLoadList
                )
              )
            )

            NavigationLink(
              "Lists: Load data then navigate",
              destination: LoadThenNavigateListView(
                store: self.store.scope(
                  state: \.loadThenNavigateList,
                  action: RootAction.loadThenNavigateList
                )
              )
            )

            NavigationLink(
              "Sheets: Present and load data",
              destination: PresentAndLoadView(
                store: self.store.scope(
                  state: \.presentAndLoad,
                  action: RootAction.presentAndLoad
                )
              )
            )

            NavigationLink(
              "Sheets: Load data then present",
              destination: LoadThenPresentView(
                store: self.store.scope(
                  state: \.loadThenPresent,
                  action: RootAction.loadThenPresent
                )
              )
            )
          }

          Section(header: Text("Higher-order reducers")) {
            NavigationLink(
              "Reusable favoriting component",
              destination: EpisodesView(
                store: self.store.scope(
                  state: \.episodes,
                  action: RootAction.episodes
                )
              )
            )

            NavigationLink(
              "Reusable offline download component",
              destination: CitiesView(
                store: self.store.scope(
                  state: \.map,
                  action: RootAction.map
                )
              )
            )

            NavigationLink(
              "Lifecycle",
              destination: LifecycleDemoView(
                store: self.store.scope(
                  state: \.lifecycle,
                  action: RootAction.lifecycle
                )
              )
            )

            NavigationLink(
              "Strict reducers",
              destination: DieRollView(
                store: self.store.scope(
                  state: \.dieRoll,
                  action: RootAction.dieRoll
                )
              )
            )

            NavigationLink(
              "Elm-like subscriptions",
              destination: ClockView(
                store: self.store.scope(
                  state: \.clock,
                  action: RootAction.clock
                )
              )
            )

            NavigationLink(
              "Recursive state and actions",
              destination: NestedView(
                store: self.store.scope(
                  state: \.nested,
                  action: RootAction.nested
                )
              )
            )
          }
        }
        .navigationBarTitle("Case Studies")
        .onAppear { viewStore.send(.onAppear) }
      }
    }
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView(
      store: .init(
        initialState: RootState(),
        reducer: rootReducer,
        environment: .live
      )
    )
  }
}
