import ComposableArchitecture
import SwiftUI

struct RootView: View {
  @State var isNavigationStackCaseStudyPresented = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink("Basics") {
            CounterDemoView(
              store: Store(initialState: Counter.State()) {
                Counter()
              }
            )
          }
          NavigationLink("Combining reducers") {
            TwoCountersView(
              store: Store(initialState: TwoCounters.State()) {
                TwoCounters()
              }
            )
          }
          NavigationLink("Bindings") {
            BindingBasicsView(
              store: Store(initialState: BindingBasics.State()) {
                BindingBasics()
              }
            )
          }
          NavigationLink("Form bindings") {
            BindingFormView(
              store: Store(initialState: BindingForm.State()) {
                BindingForm()
              }
            )
          }
          NavigationLink("Optional state") {
            OptionalBasicsView(
              store: Store(initialState: OptionalBasics.State()) {
                OptionalBasics()
              }
            )
          }
          NavigationLink("Shared state") {
            SharedStateView(
              store: Store(initialState: SharedState.State()) {
                SharedState()
              }
            )
          }
          NavigationLink("Alerts and Confirmation Dialogs") {
            AlertAndConfirmationDialogView(
              store: Store(initialState: AlertAndConfirmationDialog.State()) {
                AlertAndConfirmationDialog()
              }
            )
          }
          NavigationLink("Focus State") {
            FocusDemoView(
              store: Store(initialState: FocusDemo.State()) {
                FocusDemo()
              }
            )
          }
          NavigationLink("Animations") {
            AnimationsView(
              store: Store(initialState: Animations.State()) {
                Animations()
              }
            )
          }
        } header: {
          Text("Getting started")
        }

        Section {
          NavigationLink("Basics") {
            EffectsBasicsView(
              store: Store(initialState: EffectsBasics.State()) {
                EffectsBasics()
              }
            )
          }
          NavigationLink("Cancellation") {
            EffectsCancellationView(
              store: Store(initialState: EffectsCancellation.State()) {
                EffectsCancellation()
              }
            )
          }
          NavigationLink("Long-living effects") {
            LongLivingEffectsView(
              store: Store(initialState: LongLivingEffects.State()) {
                LongLivingEffects()
              }
            )
          }
          NavigationLink("Refreshable") {
            RefreshableView(
              store: Store(initialState: Refreshable.State()) {
                Refreshable()
              }
            )
          }
          NavigationLink("Timers") {
            TimersView(
              store: Store(initialState: Timers.State()) {
                Timers()
              }
            )
          }
          NavigationLink("Web socket") {
            WebSocketView(
              store: Store(initialState: WebSocket.State()) {
                WebSocket()
              }
            )
          }
        } header: {
          Text("Effects")
        }

        Section {
          Button("Stack") {
            self.isNavigationStackCaseStudyPresented = true
          }
          .buttonStyle(.plain)

          NavigationLink("Navigate and load data") {
            NavigateAndLoadView(
              store: Store(initialState: NavigateAndLoad.State()) {
                NavigateAndLoad()
              }
            )
          }

          NavigationLink("Lists: Navigate and load data") {
            NavigateAndLoadListView(
              store: Store(initialState: NavigateAndLoadList.State()) {
                NavigateAndLoadList()
              }
            )
          }
          NavigationLink("Sheets: Present and load data") {
            PresentAndLoadView(
              store: Store(initialState: PresentAndLoad.State()) {
                PresentAndLoad()
              }
            )
          }
          NavigationLink("Sheets: Load data then present") {
            LoadThenPresentView(
              store: Store(initialState: LoadThenPresent.State()) {
                LoadThenPresent()
              }
            )
          }
          NavigationLink("Multiple destinations") {
            MultipleDestinationsView(
              store: Store(initialState: MultipleDestinations.State()) {
                MultipleDestinations()
              }
            )
          }
        } header: {
          Text("Navigation")
        }

        Section {
          NavigationLink("Reusable favoriting component") {
            EpisodesView(
              store: Store(initialState: Episodes.State()) {
                Episodes()
              }
            )
          }
          NavigationLink("Reusable offline download component") {
            CitiesView(
              store: Store(initialState: MapApp.State()) {
                MapApp()
              }
            )
          }
          NavigationLink("Recursive state and actions") {
            NestedView(
              store: Store(initialState: Nested.State()) {
                Nested()
              }
            )
          }
        } header: {
          Text("Higher-order reducers")
        }
      }
      .navigationTitle("Case Studies")
      .sheet(isPresented: self.$isNavigationStackCaseStudyPresented) {
        NavigationDemoView(
          store: Store(initialState: NavigationDemo.State()) {
            NavigationDemo()
          }
        )
      }
    }
  }
}

#Preview {
  RootView()
}
