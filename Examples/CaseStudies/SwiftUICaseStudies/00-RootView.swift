import ComposableArchitecture
import SwiftUI

struct RootView: View {
  @State var isNavigationStackCaseStudyPresented = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink("Basics") {
            CounterDemoView()
          }
          NavigationLink("Combining reducers") {
            TwoCountersView()
          }
          NavigationLink("Bindings") {
            BindingBasicsView()
          }
          NavigationLink("Form bindings") {
            BindingFormView()
          }
          NavigationLink("Optional state") {
            OptionalBasicsView()
          }
          NavigationLink("Shared state") {
            SharedStateView()
          }
          NavigationLink("Alerts and Confirmation Dialogs") {
            AlertAndConfirmationDialogView()
          }
          NavigationLink("Focus State") {
            FocusDemoView()
          }
          NavigationLink("Animations") {
            AnimationsView()
          }
        } header: {
          Text("Getting started")
        }

        Section {
          NavigationLink("Basics") {
            EffectsBasicsView()
          }
          NavigationLink("Cancellation") {
            EffectsCancellationView()
          }
          NavigationLink("Long-living effects") {
            LongLivingEffectsView()
          }
          NavigationLink("Refreshable") {
            RefreshableView()
          }
          NavigationLink("Timers") {
            TimersView()
          }
          NavigationLink("Web socket") {
            WebSocketView()
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
            NavigateAndLoadView()
          }

          NavigationLink("Lists: Navigate and load data") {
            NavigateAndLoadListView()
          }
          NavigationLink("Sheets: Present and load data") {
            PresentAndLoadView()
          }
          NavigationLink("Sheets: Load data then present") {
            LoadThenPresentView()
          }
          NavigationLink("Multiple destinations") {
            MultipleDestinationsView()
          }
        } header: {
          Text("Navigation")
        }

        Section {
          NavigationLink("Reusable favoriting component") {
            EpisodesView()
          }
          NavigationLink("Reusable offline download component") {
            CitiesView()
          }
          NavigationLink("Recursive state and actions") {
            NestedView()
          }
        } header: {
          Text("Higher-order reducers")
        }
      }
      .navigationTitle("Case Studies")
      .sheet(isPresented: self.$isNavigationStackCaseStudyPresented) {
        NavigationDemoView()
      }
    }
  }
}

// MARK: - SwiftUI previews

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
