import ComposableArchitecture
import SwiftUI

struct RootView: View {
  @State var isNavigationStackCaseStudyPresented = false
  let store: StoreOf<Root>

  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink("Basics") {
            CounterDemoView(
              store: self.store.scope(state: \.counter, action: { .counter($0) })
            )
          }
          NavigationLink("Combining reducers") {
            TwoCountersView(
              store: self.store.scope(state: \.twoCounters, action: { .twoCounters($0) })
            )
          }
          NavigationLink("Bindings") {
            BindingBasicsView(
              store: self.store.scope(state: \.bindingBasics, action: { .bindingBasics($0) })
            )
          }
          NavigationLink("Form bindings") {
            BindingFormView(
              store: self.store.scope(state: \.bindingForm, action: { .bindingForm($0) })
            )
          }
          NavigationLink("Optional state") {
            OptionalBasicsView(
              store: self.store.scope(state: \.optionalBasics, action: { .optionalBasics($0) })
            )
          }
          NavigationLink("Shared state") {
            SharedStateView(
              store: self.store.scope(state: \.shared, action: { .shared($0) })
            )
          }
          NavigationLink("Alerts and Confirmation Dialogs") {
            AlertAndConfirmationDialogView(
              store: self.store.scope(
                state: \.alertAndConfirmationDialog,
                action: { .alertAndConfirmationDialog($0) }
              )
            )
          }
          NavigationLink("Focus State") {
            FocusDemoView(
              store: self.store.scope(state: \.focusDemo, action: { .focusDemo($0) })
            )
          }
          NavigationLink("Animations") {
            AnimationsView(
              store: self.store.scope(state: \.animation, action: { .animation($0) })
            )
          }
        } header: {
          Text("Getting started")
        }

        Section {
          NavigationLink("Basics") {
            EffectsBasicsView(
              store: self.store.scope(state: \.effectsBasics, action: { .effectsBasics($0) })
            )
          }
          NavigationLink("Cancellation") {
            EffectsCancellationView(
              store: self.store.scope(
                state: \.effectsCancellation,
                action: { .effectsCancellation($0) }
              )
            )
          }
          NavigationLink("Long-living effects") {
            LongLivingEffectsView(
              store: self.store.scope(
                state: \.longLivingEffects,
                action: { .longLivingEffects($0) }
              )
            )
          }
          NavigationLink("Refreshable") {
            RefreshableView(
              store: self.store.scope(state: \.refreshable, action: { .refreshable($0) })
            )
          }
          NavigationLink("Timers") {
            TimersView(
              store: self.store.scope(state: \.timers, action: { .timers($0) })
            )
          }
          NavigationLink("Web socket") {
            WebSocketView(
              store: self.store.scope(state: \.webSocket, action: { .webSocket($0) })
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
              store: self.store.scope(state: \.navigateAndLoad, action: { .navigateAndLoad($0) })
            )
          }

          NavigationLink("Lists: Navigate and load data") {
            NavigateAndLoadListView(
              store: self.store.scope(
                state: \.navigateAndLoadList, action: { .navigateAndLoadList($0) }
              )
            )
          }
          NavigationLink("Sheets: Present and load data") {
            PresentAndLoadView(
              store: self.store.scope(state: \.presentAndLoad, action: { .presentAndLoad($0) })
            )
          }
          NavigationLink("Sheets: Load data then present") {
            LoadThenPresentView(
              store: self.store.scope(state: \.loadThenPresent, action: { .loadThenPresent($0) })
            )
          }
          NavigationLink("Multiple destinations") {
            MultipleDestinationsView(
              store: self.store.scope(
                state: \.multipleDestinations,
                action: { .multipleDestinations($0) }
              )
            )
          }
        } header: {
          Text("Navigation")
        }

        Section {
          NavigationLink("Reusable favoriting component") {
            EpisodesView(
              store: self.store.scope(state: \.episodes, action: { .episodes($0) })
            )
          }
          NavigationLink("Reusable offline download component") {
            CitiesView(
              store: self.store.scope(state: \.map, action: { .map($0) })
            )
          }
          NavigationLink("Recursive state and actions") {
            NestedView(
              store: self.store.scope(state: \.nested, action: { .nested($0) })
            )
          }
        } header: {
          Text("Higher-order reducers")
        }
      }
      .navigationTitle("Case Studies")
      .onAppear { self.store.send(.onAppear) }
      .sheet(isPresented: self.$isNavigationStackCaseStudyPresented) {
        NavigationDemoView(
          store: self.store.scope(
            state: \.navigationStack,
            action: { .navigationStack($0) }
          )
        )
      }
    }
  }
}

// MARK: - SwiftUI previews

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView(
      store: Store(initialState: Root.State()) {
        Root()
      }
    )
  }
}
