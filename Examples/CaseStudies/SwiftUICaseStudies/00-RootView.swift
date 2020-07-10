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
                  state: { $0.counter },
                  action: RootAction.counter
                )
              )
            )

            NavigationLink(
              "Pullback and combine",
              destination: TwoCountersView(
                store: self.store.scope(
                  state: { $0.twoCounters },
                  action: RootAction.twoCounters
                )
              )
            )

            NavigationLink(
              "Bindings",
              destination: BindingBasicsView(
                store: self.store.scope(
                  state: { $0.bindingBasics },
                  action: RootAction.bindingBasics
                )
              )
            )

            NavigationLink(
              "Optional state",
              destination: OptionalBasicsView(
                store: self.store.scope(
                  state: { $0.optionalBasics },
                  action: RootAction.optionalBasics
                )
              )
            )

            NavigationLink(
              "Shared state",
              destination: SharedStateView(
                store: self.store.scope(
                  state: { $0.shared },
                  action: RootAction.shared
                )
              )
            )

            NavigationLink(
              "Alerts and Action Sheets",
              destination: AlertAndSheetView(
                store: self.store.scope(
                  state: { $0.alertAndActionSheet },
                  action: RootAction.alertAndActionSheet
                )
              )
            )

            NavigationLink(
              "Animations",
              destination: AnimationsView(
                store: self.store.scope(
                  state: { $0.animation },
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
                  state: { $0.effectsBasics },
                  action: RootAction.effectsBasics
                )
              )
            )

            NavigationLink(
              "Cancellation",
              destination: EffectsCancellationView(
                store: self.store.scope(
                  state: { $0.effectsCancellation },
                  action: RootAction.effectsCancellation)
              )
            )

            NavigationLink(
              "Long-living effects",
              destination: LongLivingEffectsView(
                store: self.store.scope(
                  state: { $0.longLivingEffects },
                  action: RootAction.longLivingEffects
                )
              )
            )

            NavigationLink(
              "Timers",
              destination: TimersView(
                store: self.store.scope(
                  state: { $0.timers },
                  action: RootAction.timers
                )
              )
            )

            NavigationLink(
              "System environment",
              destination: MultipleDependenciesView(
                store: self.store.scope(
                  state: { $0.multipleDependencies },
                  action: RootAction.multipleDependencies
                )
              )
            )

            NavigationLink(
              "Web socket",
              destination: WebSocketView(
                store: self.store.scope(
                  state: { $0.webSocket },
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
                  state: { $0.navigateAndLoad },
                  action: RootAction.navigateAndLoad
                )
              )
            )

            NavigationLink(
              "Load data then navigate",
              destination: LoadThenNavigateView(
                store: self.store.scope(
                  state: { $0.loadThenNavigate },
                  action: RootAction.loadThenNavigate
                )
              )
            )

            NavigationLink(
              "Lists: Navigate and load data",
              destination: NavigateAndLoadListView(
                store: self.store.scope(
                  state: { $0.navigateAndLoadList },
                  action: RootAction.navigateAndLoadList
                )
              )
            )

            NavigationLink(
              "Lists: Load data then navigate",
              destination: LoadThenNavigateListView(
                store: self.store.scope(
                  state: { $0.loadThenNavigateList },
                  action: RootAction.loadThenNavigateList
                )
              )
            )

            NavigationLink(
              "Sheets: Present and load data",
              destination: PresentAndLoadView(
                store: self.store.scope(
                  state: { $0.presentAndLoad },
                  action: RootAction.presentAndLoad
                )
              )
            )

            NavigationLink(
              "Sheets: Load data then present",
              destination: LoadThenPresentView(
                store: self.store.scope(
                  state: { $0.loadThenPresent },
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
                  state: { $0.episodes },
                  action: RootAction.episodes
                )
              )
            )

            NavigationLink(
              "Reusable offline download component",
              destination: CitiesView(
                store: self.store.scope(
                  state: { $0.map },
                  action: RootAction.map
                )
              )
            )

            NavigationLink(
              "Lifecycle",
              destination: LifecycleDemoView(
                store: self.store.scope(
                  state: { $0.lifecycle },
                  action: RootAction.lifecycle
                )
              )
            )

            NavigationLink(
              "Strict reducers",
              destination: DieRollView(
                store: self.store.scope(
                  state: { $0.dieRoll },
                  action: RootAction.dieRoll
                )
              )
            )

            NavigationLink(
              "Elm-like subscriptions",
              destination: ClockView(
                store: self.store.scope(
                  state: { $0.clock },
                  action: RootAction.clock
                )
              )
            )

            NavigationLink(
              "Recursive state and actions",
              destination: NestedView(
                store: self.store.scope(
                  state: { $0.nested },
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
