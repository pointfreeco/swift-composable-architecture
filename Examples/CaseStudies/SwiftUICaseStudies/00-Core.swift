import Combine
import ComposableArchitecture
import UIKit

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
  var episodes = EpisodesState(episodes: .mocks)
  var loadThenNavigate = LoadThenNavigateState()
  var loadThenNavigateList = LoadThenNavigateListState()
  var loadThenPresent = LoadThenPresentState()
  var longLivingEffects = LongLivingEffectsState()
  var map = MapAppState(cityMaps: .mocks)
  var multipleDependencies = MultipleDependenciesState()
  var navigateAndLoad = NavigateAndLoadState()
  var navigateAndLoadList = NavigateAndLoadListState()
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
  case onAppear
  case presentAndLoad(PresentAndLoadAction)
  case shared(SharedStateAction)
  case timers(TimersAction)
  case twoCounters(TwoCountersAction)
  case webSocket(WebSocketAction)
}

struct RootEnvironment {
  var date: () -> Date
  var downloadClient: DownloadClient
  var favorite: (UUID, Bool) -> Effect<Bool, Error>
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
    fetchNumber: liveFetchNumber,
    mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
    numberFact: liveNumberFact(for:),
    trivia: liveTrivia(for:),
    userDidTakeScreenshot: liveUserDidTakeScreenshot,
    uuid: UUID.init,
    webSocket: .live
  )
}

let rootReducer = Reducer<RootState, RootAction, RootEnvironment>.combine(
  .init { state, action, _ in
    switch action {
    case .onAppear:
      state = .init()
      return .none

    default:
      return .none
    }
  },
  alertAndSheetReducer
    .pullback(
      state: \RootState.alertAndActionSheet,
      action: /RootAction.alertAndActionSheet,
      environment: { _ in .init() }
    ),
  animationsReducer
    .pullback(
      state: \RootState.animation,
      action: /RootAction.animation,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  bindingBasicsReducer
    .pullback(
      state: \RootState.bindingBasics,
      action: /RootAction.bindingBasics,
      environment: { _ in .init() }
    ),
  clockReducer
    .pullback(
      state: \RootState.clock,
      action: /RootAction.clock,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  counterReducer
    .pullback(
      state: \RootState.counter,
      action: /RootAction.counter,
      environment: { _ in .init() }
    ),
  dieRollReducer
    .pullback(
      state: \RootState.dieRoll,
      action: /RootAction.dieRoll,
      environment: { _ in .init(rollDie: { .random(in: 1...6) }) }
    ),
  effectsBasicsReducer
    .pullback(
      state: \RootState.effectsBasics,
      action: /RootAction.effectsBasics,
      environment: { .init(mainQueue: $0.mainQueue, numberFact: $0.numberFact) }
    ),
  effectsCancellationReducer
    .pullback(
      state: \RootState.effectsCancellation,
      action: /RootAction.effectsCancellation,
      environment: { .init(mainQueue: $0.mainQueue, trivia: $0.trivia) }
    ),
  episodesReducer
    .pullback(
      state: \RootState.episodes,
      action: /RootAction.episodes,
      environment: { .init(favorite: $0.favorite, mainQueue: $0.mainQueue) }
    ),
  loadThenNavigateReducer
    .pullback(
      state: \RootState.loadThenNavigate,
      action: /RootAction.loadThenNavigate,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  loadThenNavigateListReducer
    .pullback(
      state: \RootState.loadThenNavigateList,
      action: /RootAction.loadThenNavigateList,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  loadThenPresentReducer
    .pullback(
      state: \RootState.loadThenPresent,
      action: /RootAction.loadThenPresent,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  longLivingEffectsReducer
    .pullback(
      state: \RootState.longLivingEffects,
      action: /RootAction.longLivingEffects,
      environment: { .init(userDidTakeScreenshot: $0.userDidTakeScreenshot) }
    ),
  mapAppReducer
    .pullback(
      state: \RootState.map,
      action: /RootAction.map,
      environment: { .init(downloadClient: $0.downloadClient, mainQueue: $0.mainQueue) }
    ),
  multipleDependenciesReducer
    .pullback(
      state: \RootState.multipleDependencies,
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
  navigateAndLoadReducer
    .pullback(
      state: \RootState.navigateAndLoad,
      action: /RootAction.navigateAndLoad,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  navigateAndLoadListReducer
    .pullback(
      state: \RootState.navigateAndLoadList,
      action: /RootAction.navigateAndLoadList,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  nestedReducer
    .pullback(
      state: \RootState.nested,
      action: /RootAction.nested,
      environment: { .init(uuid: $0.uuid) }
    ),
  optionalBasicsReducer
    .pullback(
      state: \RootState.optionalBasics,
      action: /RootAction.optionalBasics,
      environment: { _ in .init() }
    ),
  presentAndLoadReducer
    .pullback(
      state: \RootState.presentAndLoad,
      action: /RootAction.presentAndLoad,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  sharedStateReducer
    .pullback(
      state: \RootState.shared,
      action: /RootAction.shared,
      environment: { _ in () }
    ),
  timersReducer
    .pullback(
      state: \RootState.timers,
      action: /RootAction.timers,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  twoCountersReducer
    .pullback(
      state: \RootState.twoCounters,
      action: /RootAction.twoCounters,
      environment: { _ in .init() }
    ),
  webSocketReducer
    .pullback(
      state: \RootState.webSocket,
      action: /RootAction.webSocket,
      environment: { .init(mainQueue: $0.mainQueue, webSocket: $0.webSocket) }
    )
)
.signpost()

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

private func liveFetchNumber() -> Effect<Int, Never> {
  Deferred { Just(Int.random(in: 1...1_000)) }
    .delay(for: 1, scheduler: DispatchQueue.main)
    .eraseToEffect()
}

private let liveUserDidTakeScreenshot = NotificationCenter.default
  .publisher(for: UIApplication.userDidTakeScreenshotNotification)
  .map { _ in () }
  .eraseToEffect()
