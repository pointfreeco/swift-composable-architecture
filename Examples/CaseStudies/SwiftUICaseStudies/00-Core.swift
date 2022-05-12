import Combine
import ComposableArchitecture
import UIKit
import XCTestDynamicOverlay

struct RootState {
  var alertAndConfirmationDialog = AlertAndConfirmationDialog.State()
  var animation = AnimationsState()
  var bindingBasics = BindingBasicsState()
  #if compiler(>=5.4)
    var bindingForm = BindingFormState()
  #endif
  var clock = ClockState()
  var counter = CounterState()
  var dieRoll = DieRollState()
  var effectsBasics = EffectsBasicsState()
  var effectsCancellation = EffectsCancellationState()
  var effectsTimers = TimersState()
  var episodes = EpisodesState(episodes: .mocks)
  #if compiler(>=5.5)
    var focusDemo = FocusDemoState()
  #endif
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
  case alertAndConfirmationDialog(AlertAndConfirmationDialog.Action)
  case animation(AnimationsAction)
  case bindingBasics(BindingBasicsAction)
  #if compiler(>=5.4)
    case bindingForm(BindingFormAction)
  #endif
  case clock(ClockAction)
  case counter(CounterAction)
  case dieRoll(DieRollAction)
  case effectsBasics(EffectsBasicsAction)
  case effectsCancellation(EffectsCancellationAction)
  case episodes(EpisodesAction)
  #if compiler(>=5.5)
    case focusDemo(FocusDemoAction)
  #endif
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

struct RootReducer: ReducerProtocol {
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.uuid) var uuid

  var body: some ReducerProtocol<RootState, RootAction> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state = .init()
        return .none

      default:
        return .none
      }
    }

    Pullback(state: \.alertAndConfirmationDialog, action: /RootAction.alertAndConfirmationDialog) {
      AlertAndConfirmationDialog()
    }
    Pullback(state: \.animation, action: /RootAction.animation) {
      AnimationsReducer()
    }
    Pullback(state: \.bindingBasics, action: /RootAction.bindingBasics) {
      BindingBasicsReducer()
    }
    #if compiler(>=5.4)
      Pullback(state: \.bindingForm, action: /RootAction.bindingForm) {
        BindingFormReducer()
      }
    #endif
    Pullback(state: \.clock, action: /RootAction.clock) {
      Reduce(clockReducer, environment: .init(mainQueue: self.mainQueue))
    }
    Pullback(state: \.counter, action: /RootAction.counter) {
      CounterReducer()
    }
    Pullback(state: \.dieRoll, action: /RootAction.dieRoll) {
      Reduce(dieRollReducer, environment: .init(rollDie: { .random(in: 1...6) }))
    }
    Pullback(state: \.effectsBasics, action: /RootAction.effectsBasics) {
      EffectsBasicsReducer()
    }
    Pullback(state: \.effectsCancellation, action: /RootAction.effectsCancellation) {
      EffectsCancellationReducer()
    }
    Pullback(state: \.episodes, action: /RootAction.episodes) {
      Reduce(
        episodesReducer,
        environment: .init(favorite: favorite(id:isFavorite:), mainQueue: self.mainQueue)
      )
    }
    #if compiler(>=5.5)
      Pullback(state: \.focusDemo, action: /RootAction.focusDemo) {
        Reduce(focusDemoReducer, environment: .init())
      }
    #endif
    Pullback(state: \.lifecycle, action: /RootAction.lifecycle) {
      Reduce(lifecycleDemoReducer, environment: .init(mainQueue: self.mainQueue))
    }
    Pullback(state: \.loadThenNavigate, action: /RootAction.loadThenNavigate) {
      LoadThenNavigateReducer()
    }
    Pullback(state: \.loadThenNavigateList, action: /RootAction.loadThenNavigateList) {
      LoadThenNavigateListReducer()
    }
    Pullback(state: \.loadThenPresent, action: /RootAction.loadThenPresent) {
      LoadThenPresentReducer()
    }
    Pullback(state: \.longLivingEffects, action: /RootAction.longLivingEffects) {
      LongLivingEffectsReducer()
    }
    Pullback(state: \.map, action: /RootAction.map) {
      Reduce(mapAppReducer, environment: .init(downloadClient: .live, mainQueue: self.mainQueue))
    }
    Pullback(state: \.multipleDependencies, action: /RootAction.multipleDependencies) {
      Reduce(
        multipleDependenciesReducer,
        environment: .init(
          date: Date.init,
          environment: .init(fetchNumber: liveFetchNumber),
          mainQueue: self.mainQueue,
          uuid: self.uuid.callAsFunction
        )
      )
    }
    Pullback(state: \.navigateAndLoad, action: /RootAction.navigateAndLoad) {
      NavigateAndLoadReducer()
    }
    Pullback(state: \.navigateAndLoadList, action: /RootAction.navigateAndLoadList) {
      NavigateAndLoadListReducer()
    }
    Pullback(state: \.nested, action: /RootAction.nested) {
      NestedReducer()
    }
    Pullback(state: \.optionalBasics, action: /RootAction.optionalBasics) {
      OptionalBasicsReducer()
    }
    Pullback(state: \.presentAndLoad, action: /RootAction.presentAndLoad) {
      PresentAndLoadReducer()
    }
    Pullback(state: \.refreshable, action: /RootAction.refreshable) {
      RefreshableReducer()
    }
    Pullback(state: \.shared, action: /RootAction.shared) {
      SharedStateReducer()
    }
    Pullback(state: \.timers, action: /RootAction.timers) {
      TimersReducer()
    }
    Pullback(state: \.twoCounters, action: /RootAction.twoCounters) {
      TwoCountersReducer()
    }
    Pullback(state: \.webSocket, action: /RootAction.webSocket) {
      WebSocketReducer()
    }
  }
}

private func liveFetchNumber() -> Effect<Int, Never> {
  Deferred { Just(Int.random(in: 1...1_000)) }
    .delay(for: 1, scheduler: DispatchQueue.main)
    .eraseToEffect()
}
