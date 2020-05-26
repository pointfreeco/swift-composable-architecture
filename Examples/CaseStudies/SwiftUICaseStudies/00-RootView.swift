import Combine
import ComposableArchitecture
import SwiftUI

struct RootView: View {
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Getting started")) {
          NavigationLink(
            "Basics",
            destination: CounterDemoView(
              store: Store(
                initialState: CounterState(),
                reducer: counterReducer,
                environment: CounterEnvironment()
              )
            )
          )

          NavigationLink(
            "Pullback and combine",
            destination: TwoCountersView(
              store: Store(
                initialState: TwoCountersState(),
                reducer: twoCountersReducer,
                environment: TwoCountersEnvironment()
              )
            )
          )

          NavigationLink(
            "Bindings",
            destination: BindingBasicsView(
              store: Store(
                initialState: BindingBasicsState(),
                reducer: bindingBasicsReducer,
                environment: BindingBasicsEnvironment()
              )
            )
          )

          NavigationLink(
            "Optional state",
            destination: OptionalBasicsView(
              store: Store(
                initialState: OptionalBasicsState(),
                reducer: optionalBasicsReducer,
                environment: OptionalBasicsEnvironment()
              )
            )
          )

          NavigationLink(
            "Shared state",
            destination: SharedStateView(
              store: Store(
                initialState: SharedState(),
                reducer: sharedStateReducer,
                environment: ()
              )
            )
          )

          NavigationLink(
            "Animations",
            destination: AnimationsView(
              store: Store(
                initialState: AnimationsState(circleCenter: CGPoint(x: 50, y: 50)),
                reducer: animationsReducer,
                environment: AnimationsEnvironment()
              )
            )
          )
        }

        Section(header: Text("Effects")) {
          NavigationLink(
            "Basics",
            destination: EffectsBasicsView(
              store: Store(
                initialState: EffectsBasicsState(),
                reducer: effectsBasicsReducer,
                environment: .live
              )
            )
          )

          NavigationLink(
            "Cancellation",
            destination: EffectsCancellationView(
              store: Store(
                initialState: .init(),
                reducer: effectsCancellationReducer,
                environment: .live)
            )
          )

          NavigationLink(
            "Long-living effects",
            destination: LongLivingEffectsView(
              store: Store(
                initialState: LongLivingEffectsState(),
                reducer: longLivingEffectsReducer,
                environment: .live
              )
            )
          )

          NavigationLink(
            "Timers",
            destination: TimersView(
              store: Store(
                initialState: TimersState(),
                reducer: timersReducer,
                environment: TimersEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "System environment",
            destination: MultipleDependenciesView(
              store: Store(
                initialState: MultipleDependenciesState(),
                reducer: multipleDependenciesReducer,
                environment: .live(
                  environment: MultipleDependenciesEnvironment(
                    fetchNumber: {
                      Effect(value: Int.random(in: 1...1_000))
                        .delay(for: 1, scheduler: DispatchQueue.main)
                        .eraseToEffect()
                    }
                  )
                )
              )
            )
          )
        }

        Section(header: Text("Navigation")) {
          NavigationLink(
            "Navigate and load data",
            destination: EagerNavigationView(
              store: Store(
                initialState: EagerNavigationState(),
                reducer: eagerNavigationReducer,
                environment: EagerNavigationEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Load data then navigate",
            destination: LazyNavigationView(
              store: Store(
                initialState: LazyNavigationState(),
                reducer: lazyNavigationReducer,
                environment: LazyNavigationEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Lists: Navigate and load data",
            destination: EagerListNavigationView(
              store: Store(
                initialState: EagerListNavigationState(
                  rows: [
                    .init(count: 1, id: UUID()),
                    .init(count: 42, id: UUID()),
                    .init(count: 100, id: UUID()),
                  ]
                ),
                reducer: eagerListNavigationReducer,
                environment: EagerListNavigationEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Lists: Load data then navigate",
            destination: LazyListNavigationView(
              store: Store(
                initialState: LazyListNavigationState(
                  rows: [
                    .init(count: 1, id: UUID()),
                    .init(count: 42, id: UUID()),
                    .init(count: 100, id: UUID()),
                  ]
                ),
                reducer: lazyListNavigationReducer,
                environment: LazyListNavigationEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Sheets: Present and load data",
            destination: EagerSheetView(
              store: Store(
                initialState: EagerSheetState(),
                reducer: eagerSheetReducer,
                environment: EagerSheetEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Sheets: Load data then present",
            destination: LazySheetView(
              store: Store(
                initialState: LazySheetState(),
                reducer: lazySheetReducer,
                environment: LazySheetEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )
        }

        Section(header: Text("Higher-order reducers")) {
          NavigationLink(
            "Reusable favoriting component",
            destination: EpisodesView(
              store: Store(
                initialState: EpisodesState(
                  episodes: .mocks
                ),
                reducer: episodesReducer,
                environment: EpisodesEnvironment(
                  favorite: favorite(id:isFavorite:),
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Reusable offline download component",
            destination: CitiesView(
              store: Store(
                initialState: .init(cityMaps: .mocks),
                reducer: mapAppReducer,
                environment: .init(
                  downloadClient: .live,
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Strict reducers",
            destination: DieRollView(
              store: Store(
                initialState: DieRollState(),
                reducer: dieRollReducer,
                environment: DieRollEnvironment(
                  rollDie: { .random(in: 1...6) }
                )
              )
            )
          )

          NavigationLink(
            "Elm-like subscriptions",
            destination: ClockView(
              store: Store(
                initialState: ClockState(),
                reducer: clockReducer,
                environment: ClockEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Recursive state and actions",
            destination: NestedView(
              store: Store(
                initialState: .mock,
                reducer: nestedReducer,
                environment: NestedEnvironment(
                  uuid: UUID.init
                )
              )
            )
          )

          NavigationLink(
            "Toast on all failures",
            destination: DataView(
              store: Store(
                initialState: AppState(),
                reducer: Reducer<AppState, AppAction, AppEnvironment>.errorHandling(appReducer),
                environment: AppEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
                  loadData: {
                    Fail(error: AppError.api)
                      .delay(for: 1, scheduler: DispatchQueue.main)
                      .eraseToEffect()
                  }
                )
              )
            )
          )
        }
      }
      .navigationBarTitle("Case Studies")
      .onAppear { self.id = UUID() }

      Text("\(self.id)")
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
  // NB: This is a hack to force the root view to re-compute itself each time it appears so that
  //     each demo is provided a fresh store each time.
  @State var id = UUID()
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
