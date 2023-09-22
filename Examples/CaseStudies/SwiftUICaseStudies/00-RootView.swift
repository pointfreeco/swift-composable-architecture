import ComposableArchitecture
import SwiftUI

struct RootView: View {
  @State var isNavigationStackCaseStudyPresented = false
  let store: StoreOf<Root>

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Getting started")) {
          NavigationLink("Basics") {
            CounterDemoView(store: self.store.scope(#feature(\.counter)))
          }
          NavigationLink("Combining reducers") {
            TwoCountersView(store: self.store.scope(#feature(\.twoCounters)))
          }
          NavigationLink("Bindings") {
            BindingBasicsView(store: self.store.scope(#feature(\.bindingBasics)))
          }
          NavigationLink("Form bindings") {
            BindingFormView(store: self.store.scope(#feature(\.bindingForm)))
          }
          NavigationLink("Optional state") {
            OptionalBasicsView(store: self.store.scope(#feature(\.optionalBasics)))
          }
          NavigationLink("Shared state") {
            SharedStateView(store: self.store.scope(#feature(\.shared)))
          }
          NavigationLink("Alerts and Confirmation Dialogs") {
            AlertAndConfirmationDialogView(
              store: self.store.scope(#feature(\.alertAndConfirmationDialog))
            )
          }
          NavigationLink("Focus State") {
            FocusDemoView(store: self.store.scope(#feature(\.focusDemo)))
          }
          NavigationLink("Animations") {
            AnimationsView(store: self.store.scope(#feature(\.animation)))
          }
        }

        Section(header: Text("Effects")) {
          NavigationLink("Basics") {
            EffectsBasicsView(store: self.store.scope(#feature(\.effectsBasics)))
          }
          NavigationLink("Cancellation") {
            EffectsCancellationView(store: self.store.scope(#feature(\.effectsCancellation)))
          }
          NavigationLink("Long-living effects") {
            LongLivingEffectsView(store: self.store.scope(#feature(\.longLivingEffects)))
          }
          NavigationLink("Refreshable") {
            RefreshableView(store: self.store.scope(#feature(\.refreshable)))
          }
          NavigationLink("Timers") {
            TimersView(store: self.store.scope(#feature(\.timers)))
          }
          NavigationLink("Web socket") {
            WebSocketView(store: self.store.scope(#feature(\.webSocket)))
          }
        }

        Section(header: Text("Navigation")) {
          Button("Stack") {
            self.isNavigationStackCaseStudyPresented = true
          }
          .buttonStyle(.plain)

          NavigationLink("Navigate and load data") {
            NavigateAndLoadView(store: self.store.scope(#feature(\.navigateAndLoad)))
          }
          NavigationLink("Lists: Navigate and load data") {
            NavigateAndLoadListView(store: self.store.scope(#feature(\.navigateAndLoadList)))
          }
          NavigationLink("Sheets: Present and load data") {
            PresentAndLoadView(store: self.store.scope(#feature(\.presentAndLoad)))
          }
          NavigationLink("Sheets: Load data then present") {
            LoadThenPresentView(store: self.store.scope(#feature(\.loadThenPresent)))
          }
          NavigationLink("Multiple destinations") {
            MultipleDestinationsView(store: self.store.scope(#feature(\.multipleDestinations)))
          }
        }

        Section(header: Text("Higher-order reducers")) {
          NavigationLink("Reusable favoriting component") {
            EpisodesView(store: self.store.scope(#feature(\.episodes)))
          }
          NavigationLink("Reusable offline download component") {
            CitiesView(store: self.store.scope(#feature(\.map)))
          }
          NavigationLink("Recursive state and actions") {
            NestedView(store: self.store.scope(#feature(\.nested)))
          }
        }
      }
      .navigationTitle("Case Studies")
      .onAppear { self.store.send(.onAppear) }
      .sheet(isPresented: self.$isNavigationStackCaseStudyPresented) {
        NavigationDemoView(store: self.store.scope(#feature(\.navigationStack)))
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
