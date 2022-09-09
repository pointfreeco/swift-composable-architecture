import Combine
import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: Store<RootState, RootAction>

  var body: some View {
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
            "Alerts and Confirmation Dialogs",
            destination: AlertAndConfirmationDialogView(
              store: self.store.scope(
                state: \.alertAndConfirmationDialog,
                action: RootAction.alertAndConfirmationDialog
              )
            )
          )

          NavigationLink(
            "Focus State",
            destination: FocusDemoView(
              store: self.store.scope(
                state: \.focusDemo,
                action: RootAction.focusDemo
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

          NavigationLink(
            "Refreshable",
            destination: RefreshableView(
              store: self.store.scope(
                state: \.refreshable,
                action: RootAction.refreshable
              )
            )
          )

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
      .navigationTitle("Case Studies")
      .onAppear { ViewStore(self.store).send(.onAppear) }
    }
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView(
      store: Store(
        initialState: RootState(),
        reducer: rootReducer,
        environment: .live
      )
    )
  }
}
