import Combine
import ComposableArchitecture
import SwiftUI

struct RootState {
  var alertAndActionSheet = AlertAndSheetState()
  var animation = AnimationsState()
  var bindingBasics = BindingBasicsState()
  var clock = ClockState()
  var counter = CounterState()
  var dieRoll = DieRollState()
  var effectsBasics = EffectsBasicsState()
  var effectsCancellation = EffectsCancellationState()
  var effectsTimers = TimersState()
  var episodes = EpisodesState(
    episodes: .mocks
  )
  var loadThenNavigate = LoadThenNavigateState()
  var loadThenNavigateList = LoadThenNavigateListState(
    rows: [
      .init(count: 1, id: UUID()),
      .init(count: 42, id: UUID()),
      .init(count: 100, id: UUID()),
    ]
  )
  var loadThenPresent = LoadThenPresentState()
  var longLivingEffects = LongLivingEffectsState()
  var map = MapAppState(cityMaps: .mocks)
  var multipleDependencies = MultipleDependenciesState()
  var navigateAndLoad = NavigateAndLoadState()
  var navigateAndLoadList = NavigateAndLoadListState(
    rows: [
      .init(count: 1, id: UUID()),
      .init(count: 42, id: UUID()),
      .init(count: 100, id: UUID()),
    ]
  )
  var nested = NestedState.mock
  var optionalBasics = OptionalBasicsState()
  var presentAndLoad = PresentAndLoadState()
  var shared = SharedState()
  var timers = TimersState()
  var twoCounters = TwoCountersState()
  var webSocket = WebSocketState()
}

enum RootAction {
  case alertAndActionSheet(AlertAndSheetAction)
  case animation(AnimationsAction)
  case bindingBasics(BindingBasicsAction)
  case clock(ClockAction)
  case counter(CounterAction)
  case dieRoll(DieRollAction)
  case effectsBasics(EffectsBasicsAction)
  case effectsCancellation(EffectsCancellationAction)
  case episodes(EpisodesAction)
  case loadThenNavigate(LoadThenNavigateAction)
  case loadThenNavigateList(LoadThenNavigateListAction)
  case loadThenPresent(LoadThenPresentAction)
  case longLivingEffects(LongLivingEffectsAction)
  case map(MapAppAction)
  case multipleDependencies(MultipleDependenciesAction)
  case navigateAndLoad(NavigateAndLoadAction)
  case navigateAndLoadList(NavigateAndLoadListAction)
  case nested(NestedAction)
  case optionalBasics(OptionalBasicsAction)
  case presentAndLoad(PresentAndLoadAction)
  case shared(SharedStateAction)
  case timers(TimersAction)
  case twoCounters(TwoCountersAction)
  case webSocket(WebSocketAction)
}

struct RootEnvironment {
  var date: () -> Date
  var downloadClient:  DownloadClient
  var favorite: (UUID, Bool) ->  Effect<Bool, Error>
  var fetchNumber: () -> Effect<Int, Never>
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var numberFact: (Int) -> Effect<String, NumbersApiError>
  var trivia: (Int) -> Effect<String, TriviaApiError>
  var userDidTakeScreenshot: Effect<Void, Never>
  var uuid: () -> UUID
  var webSocket: WebSocketClient

  static let live = Self(
    date: Date.init,
    downloadClient: .live,
    favorite: favorite(id:isFavorite:),
    fetchNumber: {
      Effect(value: Int.random(in: 1...1_000))
        .delay(for: 1, scheduler: DispatchQueue.main)
        .eraseToEffect()
    },
    mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
    numberFact: liveNumberFact(for:),
    trivia: liveTrivia(for:),
    userDidTakeScreenshot: NotificationCenter.default
      .publisher(for: UIApplication.userDidTakeScreenshotNotification)
      .map { _ in () }
      .eraseToEffect(),
    uuid: UUID.init,
    webSocket: .live
  )
}

let rootReducer = Reducer<RootState, RootAction, RootEnvironment>.combine(
  // 01 - Getting Started
  alertAndSheetReducer
    .pullback(
      state: \.alertAndActionSheet,
      action: /RootAction.alertAndActionSheet,
      environment: { _ in .init() }
    ),
  animationsReducer
    .pullback(
      state: \.animation,
      action: /RootAction.animation,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  bindingBasicsReducer
    .pullback(
      state: \.bindingBasics,
      action: /RootAction.bindingBasics,
      environment: { _ in .init() }
    ),
  counterReducer
    .pullback(
      state: \.counter,
      action: /RootAction.counter,
      environment: { _ in .init() }
    ),
  optionalBasicsReducer
    .pullback(
      state: \.optionalBasics,
      action: /RootAction.optionalBasics,
      environment: { _ in .init() }
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
      environment: { _ in .init() }
    ),

  // 02 - Effects
  effectsBasicsReducer
    .pullback(
      state: \.effectsBasics,
      action: /RootAction.effectsBasics,
      environment: { .init(mainQueue: $0.mainQueue, numberFact: $0.numberFact ) }
    ),
  effectsCancellationReducer
    .pullback(
      state: \.effectsCancellation,
      action: /RootAction.effectsCancellation,
      environment: { .init(mainQueue: $0.mainQueue, trivia: $0.trivia) }
    ),
  longLivingEffectsReducer
    .pullback(
      state: \.longLivingEffects,
      action: /RootAction.longLivingEffects,
      environment: { .init(userDidTakeScreenshot: $0.userDidTakeScreenshot) }
    ),
  multipleDependenciesReducer
    .pullback(
      state: \.multipleDependencies,
      action: /RootAction.multipleDependencies,
      environment: { env in
        .init(
          date: env.date,
          environment: .init(fetchNumber: env.fetchNumber),
          mainQueue: { env.mainQueue },
          uuid: env.uuid
        )
      }
    ),
  timersReducer
    .pullback(
      state: \.timers,
      action: /RootAction.timers,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  webSocketReducer
    .pullback(
      state: \.webSocket,
      action: /RootAction.webSocket,
      environment: { .init(mainQueue: $0.mainQueue, webSocket: $0.webSocket) }
    ),

  // 03 - Navigation
  navigateAndLoadReducer
    .pullback(
      state: \.navigateAndLoad,
      action: /RootAction.navigateAndLoad,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  loadThenNavigateReducer
    .pullback(
      state: \.loadThenNavigate,
      action: /RootAction.loadThenNavigate,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  navigateAndLoadListReducer
    .pullback(
      state: \.navigateAndLoadList,
      action: /RootAction.navigateAndLoadList,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  loadThenNavigateListReducer
    .pullback(
      state: \.loadThenNavigateList,
      action: /RootAction.loadThenNavigateList,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  presentAndLoadReducer
    .pullback(
      state: \.presentAndLoad,
      action: /RootAction.presentAndLoad,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  loadThenPresentReducer
    .pullback(
      state: \.loadThenPresent,
      action: /RootAction.loadThenPresent,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),

  // 04 - Higher order reducers
  episodesReducer
    .pullback(
      state: \.episodes,
      action: /RootAction.episodes,
      environment: { .init(favorite: $0.favorite, mainQueue: $0.mainQueue) }
    ),
  mapAppReducer
    .pullback(
      state: \.map,
      action: /RootAction.map,
      environment: { .init(downloadClient: $0.downloadClient, mainQueue: $0.mainQueue) }
    ),
  dieRollReducer
    .pullback(
      state: \.dieRoll,
      action: /RootAction.dieRoll,
      environment: { _ in .init(rollDie: { .random(in: 1...6) }) }
    ),
  clockReducer
    .pullback(
      state: \.clock,
      action: /RootAction.clock,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  nestedReducer
    .pullback(
      state: \.nested,
      action: /RootAction.nested,
      environment: { .init(uuid: $0.uuid) }
    )
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
