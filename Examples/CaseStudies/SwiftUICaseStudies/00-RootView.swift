import ComposableArchitecture
import SwiftUI

struct RootView: View {
  @State var isNavigationStackCaseStudyPresented = false
  @State var isSignUpCaseStudyPresented = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink("Basics") {
            Demo(store: Store(initialState: Counter.State()) { Counter() }) { store in
              CounterDemoView(store: store)
            }
          }
          NavigationLink("Combining reducers") {
            Demo(store: Store(initialState: TwoCounters.State()) { TwoCounters() }) { store in
              TwoCountersView(store: store)
            }
          }
          NavigationLink("Bindings") {
            Demo(store: Store(initialState: BindingBasics.State()) { BindingBasics() }) { store in
              BindingBasicsView(store: store)
            }
          }
          NavigationLink("Form bindings") {
            Demo(store: Store(initialState: BindingForm.State()) { BindingForm() }) { store in
              BindingFormView(store: store)
            }
          }
          NavigationLink("Optional state") {
            Demo(store: Store(initialState: OptionalBasics.State()) { OptionalBasics() }) { store in
              OptionalBasicsView(store: store)
            }
          }
          NavigationLink("Alerts and Confirmation Dialogs") {
            Demo(
              store: Store(initialState: AlertAndConfirmationDialog.State()) {
                AlertAndConfirmationDialog()
              }
            ) { store in
              AlertAndConfirmationDialogView(store: store)
            }
          }
          NavigationLink("Focus State") {
            Demo(store: Store(initialState: FocusDemo.State()) { FocusDemo() }) { store in
              FocusDemoView(store: store)
            }
          }
          NavigationLink("Animations") {
            Demo(store: Store(initialState: Animations.State()) { Animations() }) { store in
              AnimationsView(store: store)
            }
          }
        } header: {
          Text("Getting started")
        }

        Section {
          NavigationLink("In memory") {
            Demo(
              store: Store(initialState: SharedStateInMemory.State()) { SharedStateInMemory() }
            ) { store in
              SharedStateInMemoryView(store: store)
            }
          }
          NavigationLink("User defaults") {
            Demo(
              store: Store(initialState: SharedStateUserDefaults.State()) {
                SharedStateUserDefaults()
              }
            ) { store in
              SharedStateUserDefaultsView(store: store)
            }
          }
          NavigationLink("File storage") {
            Demo(
              store: Store(initialState: SharedStateFileStorage.State()) {
                SharedStateFileStorage()
              }
            ) { store in
              SharedStateFileStorageView(store: store)
            }
          }
          NavigationLink("Notifications") {
            Demo(
              store: Store(initialState: SharedStateNotifications.State()) {
                SharedStateNotifications()
              }
            ) { store in
              SharedStateNotificationsView(store: store)
            }
          }
          Button("Sign up flow") {
            isSignUpCaseStudyPresented = true
          }
          .sheet(isPresented: $isSignUpCaseStudyPresented) {
            SignUpFlow()
          }
        } header: {
          Text("Shared state")
        }

        Section {
          NavigationLink("Basics") {
            Demo(store: Store(initialState: EffectsBasics.State()) { EffectsBasics() }) { store in
              EffectsBasicsView(store: store)
            }
          }
          NavigationLink("Cancellation") {
            Demo(
              store: Store(initialState: EffectsCancellation.State()) { EffectsCancellation() }
            ) { store in
              EffectsCancellationView(store: store)
            }
          }
          NavigationLink("Long-living effects") {
            Demo(
              store: Store(initialState: LongLivingEffects.State()) { LongLivingEffects() }
            ) { store in
              LongLivingEffectsView(store: store)
            }
          }
          NavigationLink("Refreshable") {
            Demo(store: Store(initialState: Refreshable.State()) { Refreshable() }) { store in
              RefreshableView(store: store)
            }
          }
          NavigationLink("Timers") {
            Demo(store: Store(initialState: Timers.State()) { Timers() }) { store in
              TimersView(store: store)
            }
          }
          NavigationLink("Web socket") {
            Demo(store: Store(initialState: WebSocket.State()) { WebSocket() }) { store in
              WebSocketView(store: store)
            }
          }
        } header: {
          Text("Effects")
        }

        Section {
          Button("Stack") {
            isNavigationStackCaseStudyPresented = true
          }
          .buttonStyle(.plain)

          NavigationLink("Navigate and load data") {
            Demo(
              store: Store(initialState: NavigateAndLoad.State()) { NavigateAndLoad() }
            ) { store in
              NavigateAndLoadView(store: store)
            }
          }

          NavigationLink("Lists: Navigate and load data") {
            Demo(
              store: Store(initialState: NavigateAndLoadList.State()) { NavigateAndLoadList() }
            ) { store in
              NavigateAndLoadListView(store: store)
            }
          }
          NavigationLink("Sheets: Present and load data") {
            Demo(store: Store(initialState: PresentAndLoad.State()) { PresentAndLoad() }) { store in
              PresentAndLoadView(store: store)
            }
          }
          NavigationLink("Sheets: Load data then present") {
            Demo(
              store: Store(initialState: LoadThenPresent.State()) { LoadThenPresent() }
            ) { store in
              LoadThenPresentView(store: store)
            }
          }
          NavigationLink("Multiple destinations") {
            Demo(
              store: Store(initialState: MultipleDestinations.State()) { MultipleDestinations() }
            ) { store in
              MultipleDestinationsView(store: store)
            }
          }
        } header: {
          Text("Navigation")
        }

        Section {
          NavigationLink("Reusable favoriting component") {
            Demo(
              store: Store(
                initialState: Episodes.State(episodes: .mocks)
              ) {
                Episodes()
              }
            ) { store in
              EpisodesView(store: store)
            }
          }
          NavigationLink("Reusable offline download component") {
            Demo(store: Store(initialState: MapApp.State()) { MapApp() }) { store in
              CitiesView(store: store)
            }
          }
          NavigationLink("Recursive state and actions") {
            Demo(store: Store(initialState: Nested.State()) { Nested() }) { store in
              NestedView(store: store)
            }
          }
        } header: {
          Text("Higher-order reducers")
        }
      }
      .navigationTitle("Case Studies")
      .sheet(isPresented: $isNavigationStackCaseStudyPresented) {
        Demo(store: Store(initialState: NavigationDemo.State()) { NavigationDemo() }) { store in
          NavigationDemoView(store: store)
        }
      }
    }
  }
}

/// This wrapper provides an "entry" point into an individual demo that can own a store.
struct Demo<State, Action, Content: View>: View {
  @SwiftUI.State var store: Store<State, Action>
  let content: (Store<State, Action>) -> Content

  init(
    store: Store<State, Action>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) {
    self.store = store
    self.content = content
  }

  var body: some View {
    content(store)
  }
}

#Preview {
  RootView()
}
