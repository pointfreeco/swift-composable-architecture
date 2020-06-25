import Combine
import ComposableArchitecture
import SwiftUI

struct RootState {
  var animation = AnimationsState()
  var bindingBasics = BindingBasicsState()
  var counter = CounterState()
  var effectsBasics = EffectsBasicsState()
  var effectsCancellation = EffectsCancellationState()
  var effectsTimers = TimersState()
  var longLivingEffects = LongLivingEffectsState()
  var optionalBasics = OptionalBasicsState()
  var shared = SharedState()
  var twoCounters = TwoCountersState()
}

enum RootAction {
  case animation(AnimationsAction)
  case bindingBasics(BindingBasicsAction)
  case counter(CounterAction)
  case effectsBasics(EffectsBasicsAction)
  case effectsCancellation(EffectsCancellationAction)
  case longLivingEffects(LongLivingEffectsAction)
  case optionalBasics(OptionalBasicsAction)
  case shared(SharedStateAction)
  case twoCounters(TwoCountersAction)
}

struct RootEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var numberFact: (Int) -> Effect<String, NumbersApiError>
  var trivia: (Int) -> Effect<String, TriviaApiError>
  var userDidTakeScreenshot: Effect<Void, Never>

  static let live = Self(
    mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
    numberFact: liveNumberFact(for:),
    trivia: liveTrivia(for:),
    userDidTakeScreenshot: NotificationCenter.default
      .publisher(for: UIApplication.userDidTakeScreenshotNotification)
      .map { _ in () }
      .eraseToEffect()
  )
}

let rootReducer = Reducer<RootState, RootAction, RootEnvironment>.combine(
  // 01 - Getting Started
  animationsReducer
    .pullback(
      state: \.animation,
      action: /RootAction.animation,
      environment: { _ in AnimationsEnvironment() }
    ),
  bindingBasicsReducer
    .pullback(
      state: \.bindingBasics,
      action: /RootAction.bindingBasics,
      environment: { _ in BindingBasicsEnvironment() }
    ),
  counterReducer
    .pullback(
      state: \.counter,
      action: /RootAction.counter,
      environment: { _ in CounterEnvironment() }
    ),
  optionalBasicsReducer
    .pullback(
      state: \.optionalBasics,
      action: /RootAction.optionalBasics,
      environment: { _ in OptionalBasicsEnvironment() }
    ),
  sharedStateReducer
    .pullback(
      state: \.shared,
      action: /RootAction.shared,
      environment: { _ in () }
    ),
  twoCountersReducer
    .pullback(
      state: \.twoCounters,
      action: /RootAction.twoCounters,
      environment: { _ in TwoCountersEnvironment() }
    ),

  // 02 - Effects
  effectsBasicsReducer
    .pullback(
      state: \.effectsBasics,
      action: /RootAction.effectsBasics,
      environment: { EffectsBasicsEnvironment(mainQueue: $0.mainQueue, numberFact: $0.numberFact ) }
    ),
  effectsCancellationReducer
    .pullback(
      state: \.effectsCancellation,
      action: /RootAction.effectsCancellation,
      environment: { EffectsCancellationEnvironment(mainQueue: $0.mainQueue, trivia: $0.trivia) }
    ),
  longLivingEffectsReducer
    .pullback(
      state: \.longLivingEffects,
      action: /RootAction.longLivingEffects,
      environment: { LongLivingEffectsEnvironment(userDidTakeScreenshot: $0.userDidTakeScreenshot) }
    ),


  .empty
)
.signpost()

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
              store: .init(
                initialState: .init(),
                reducer: alertAndSheetReducer,
                environment: .init()
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

          NavigationLink(
            "Web socket",
            destination: WebSocketView(
              store: Store(
                initialState: .init(),
                reducer: webSocketReducer,
                environment: WebSocketEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
                  webSocket: .live
                )
              )
            )
          )
        }

        Section(header: Text("Navigation")) {
          NavigationLink(
            "Navigate and load data",
            destination: NavigateAndLoadView(
              store: Store(
                initialState: NavigateAndLoadState(),
                reducer: navigateAndLoadReducer,
                environment: NavigateAndLoadEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Load data then navigate",
            destination: LoadThenNavigateView(
              store: Store(
                initialState: LoadThenNavigateState(),
                reducer: loadThenNavigateReducer,
                environment: LoadThenNavigateEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Lists: Navigate and load data",
            destination: NavigateAndLoadListView(
              store: Store(
                initialState: NavigateAndLoadListState(
                  rows: [
                    .init(count: 1, id: UUID()),
                    .init(count: 42, id: UUID()),
                    .init(count: 100, id: UUID()),
                  ]
                ),
                reducer: navigateAndLoadListReducer,
                environment: NavigateAndLoadListEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Lists: Load data then navigate",
            destination: LoadThenNavigateListView(
              store: Store(
                initialState: LoadThenNavigateListState(
                  rows: [
                    .init(count: 1, id: UUID()),
                    .init(count: 42, id: UUID()),
                    .init(count: 100, id: UUID()),
                  ]
                ),
                reducer: loadThenNavigateListReducer,
                environment: LoadThenNavigateListEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Sheets: Present and load data",
            destination: PresentAndLoadView(
              store: Store(
                initialState: PresentAndLoadState(),
                reducer: presentAndLoadReducer,
                environment: PresentAndLoadEnvironment(
                  mainQueue: DispatchQueue.main.eraseToAnyScheduler()
                )
              )
            )
          )

          NavigationLink(
            "Sheets: Load data then present",
            destination: LoadThenPresentView(
              store: Store(
                initialState: LoadThenPresentState(),
                reducer: loadThenPresentReducer,
                environment: LoadThenPresentEnvironment(
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
    RootView(
      store: .init(
        initialState: RootState(),
        reducer: rootReducer,
        environment: .live
      )
    )
  }
}

// This is the "live" trivia dependency that reaches into the outside world to fetch trivia.
// Typically this live implementation of the dependency would live in its own module so that the
// main feature doesn't need to compile it.
func liveNumberFact(for n: Int) -> Effect<String, NumbersApiError> {
  return URLSession.shared.dataTaskPublisher(for: URL(string: "http://numbersapi.com/\(n)/trivia")!)
    .map { data, _ in String(decoding: data, as: UTF8.self) }
    .catch { _ in
      // Sometimes numbersapi.com can be flakey, so if it ever fails we will just
      // default to a mock response.
      Just("\(n) is a good number Brent")
        .delay(for: 1, scheduler: DispatchQueue.main)
    }
    .mapError { _ in NumbersApiError() }
    .eraseToEffect()
}

// This is the "live" trivia dependency that reaches into the outside world to fetch trivia.
// Typically this live implementation of the dependency would live in its own module so that the
// main feature doesn't need to compile it.
func liveTrivia(for n: Int) -> Effect<String, TriviaApiError> {
  URLSession.shared.dataTaskPublisher(for: URL(string: "http://numbersapi.com/\(n)/trivia")!)
    .map { data, _ in String.init(decoding: data, as: UTF8.self) }
    .catch { _ in
      // Sometimes numbersapi.com can be flakey, so if it ever fails we will just
      // default to a mock response.
      Just("\(n) is a good number Brent")
        .delay(for: 1, scheduler: DispatchQueue.main)
    }
    .mapError { _ in TriviaApiError() }
    .eraseToEffect()
}
