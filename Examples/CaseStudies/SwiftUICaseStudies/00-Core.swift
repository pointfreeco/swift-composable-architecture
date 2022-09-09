import Combine
import ComposableArchitecture
import UIKit
import XCTestDynamicOverlay

struct RootState: Equatable {
  var alertAndConfirmationDialog = AlertAndConfirmationDialogState()
  var animation = AnimationsState()
  var bindingBasics = BindingBasicsState()
  var bindingForm = BindingFormState()
  var clock = ClockState()
  var counter = CounterState()
  var effectsBasics = EffectsBasicsState()
  var effectsCancellation = EffectsCancellationState()
  var effectsTimers = TimersState()
  var episodes = EpisodesState(episodes: .mocks)
  var focusDemo = FocusDemoState()
  var lifecycle = LifecycleDemoState()
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
  var refreshable = RefreshableState()
  var shared = SharedState()
  var timers = TimersState()
  var twoCounters = TwoCountersState()
  var webSocket = WebSocketState()
}

enum RootAction {
  case alertAndConfirmationDialog(AlertAndConfirmationDialogAction)
  case animation(AnimationsAction)
  case bindingBasics(BindingBasicsAction)
  case bindingForm(BindingFormAction)
  case clock(ClockAction)
  case counter(CounterAction)
  case effectsBasics(EffectsBasicsAction)
  case effectsCancellation(EffectsCancellationAction)
  case episodes(EpisodesAction)
  case focusDemo(FocusDemoAction)
  case lifecycle(LifecycleDemoAction)
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
  case refreshable(RefreshableAction)
  case shared(SharedStateAction)
  case timers(TimersAction)
  case twoCounters(TwoCountersAction)
  case webSocket(WebSocketAction)
}

struct RootEnvironment {
  var date: @Sendable () -> Date
  var downloadClient: DownloadClient
  var fact: FactClient
  var favorite: @Sendable (UUID, Bool) async throws -> Bool
  var fetchNumber: @Sendable () async throws -> Int
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var screenshots: @Sendable () async -> AsyncStream<Void>
  var uuid: @Sendable () -> UUID
  var webSocket: WebSocketClient

  static let live = Self(
    date: { Date() },
    downloadClient: .live,
    fact: .live,
    favorite: favorite(id:isFavorite:),
    fetchNumber: liveFetchNumber,
    mainQueue: .main,
    screenshots: { @MainActor in
      AsyncStream(
        NotificationCenter.default
          .notifications(named: UIApplication.userDidTakeScreenshotNotification)
          .map { _ in }
      )
    },
    uuid: { UUID() },
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
  alertAndConfirmationDialogReducer
    .pullback(
      state: \.alertAndConfirmationDialog,
      action: /RootAction.alertAndConfirmationDialog,
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
  bindingFormReducer
    .pullback(
      state: \.bindingForm,
      action: /RootAction.bindingForm,
      environment: { _ in .init() }
    ),
  clockReducer
    .pullback(
      state: \.clock,
      action: /RootAction.clock,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  counterReducer
    .pullback(
      state: \.counter,
      action: /RootAction.counter,
      environment: { _ in .init() }
    ),
  effectsBasicsReducer
    .pullback(
      state: \.effectsBasics,
      action: /RootAction.effectsBasics,
      environment: { .init(fact: $0.fact, mainQueue: $0.mainQueue) }
    ),
  effectsCancellationReducer
    .pullback(
      state: \.effectsCancellation,
      action: /RootAction.effectsCancellation,
      environment: { .init(fact: $0.fact) }
    ),
  episodesReducer
    .pullback(
      state: \.episodes,
      action: /RootAction.episodes,
      environment: { .init(favorite: $0.favorite) }
    ),
  focusDemoReducer
    .pullback(
      state: \.focusDemo,
      action: /RootAction.focusDemo,
      environment: { _ in .init() }
    ),
  lifecycleDemoReducer
    .pullback(
      state: \.lifecycle,
      action: /RootAction.lifecycle,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  loadThenNavigateReducer
    .pullback(
      state: \.loadThenNavigate,
      action: /RootAction.loadThenNavigate,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  loadThenNavigateListReducer
    .pullback(
      state: \.loadThenNavigateList,
      action: /RootAction.loadThenNavigateList,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  loadThenPresentReducer
    .pullback(
      state: \.loadThenPresent,
      action: /RootAction.loadThenPresent,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  longLivingEffectsReducer
    .pullback(
      state: \.longLivingEffects,
      action: /RootAction.longLivingEffects,
      environment: { .init(screenshots: $0.screenshots) }
    ),
  mapAppReducer
    .pullback(
      state: \.map,
      action: /RootAction.map,
      environment: { .init(downloadClient: $0.downloadClient, mainQueue: $0.mainQueue) }
    ),
  multipleDependenciesReducer
    .pullback(
      state: \.multipleDependencies,
      action: /RootAction.multipleDependencies,
      environment: { env in
        .init(
          date: env.date,
          environment: .init(fetchNumber: env.fetchNumber),
          mainQueue: env.mainQueue,
          uuid: env.uuid
        )
      }
    ),
  navigateAndLoadReducer
    .pullback(
      state: \.navigateAndLoad,
      action: /RootAction.navigateAndLoad,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  navigateAndLoadListReducer
    .pullback(
      state: \.navigateAndLoadList,
      action: /RootAction.navigateAndLoadList,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  nestedReducer
    .pullback(
      state: \.nested,
      action: /RootAction.nested,
      environment: { .init(uuid: $0.uuid) }
    ),
  optionalBasicsReducer
    .pullback(
      state: \.optionalBasics,
      action: /RootAction.optionalBasics,
      environment: { _ in .init() }
    ),
  presentAndLoadReducer
    .pullback(
      state: \.presentAndLoad,
      action: /RootAction.presentAndLoad,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  refreshableReducer
    .pullback(
      state: \.refreshable,
      action: /RootAction.refreshable,
      environment: { .init(fact: $0.fact, mainQueue: $0.mainQueue) }
    ),
  sharedStateReducer
    .pullback(
      state: \.shared,
      action: /RootAction.shared,
      environment: { _ in () }
    ),
  timersReducer
    .pullback(
      state: \.timers,
      action: /RootAction.timers,
      environment: { .init(mainQueue: $0.mainQueue) }
    ),
  twoCountersReducer
    .pullback(
      state: \.twoCounters,
      action: /RootAction.twoCounters,
      environment: { _ in .init() }
    ),
  webSocketReducer
    .pullback(
      state: \.webSocket,
      action: /RootAction.webSocket,
      environment: { .init(mainQueue: $0.mainQueue, webSocket: $0.webSocket) }
    )
)

@Sendable private func liveFetchNumber() async throws -> Int {
  try await Task.sleep(nanoseconds: NSEC_PER_SEC)
  return Int.random(in: 1...1_000)
}
