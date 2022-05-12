import Combine
import ComposableArchitecture
import UIKit
import XCTestDynamicOverlay

struct RootState {
  var alertAndConfirmationDialog = AlertAndConfirmationDialog.State()
  var animation = Animations.State()
  var bindingBasics = BindingBasics.State()
  #if compiler(>=5.4)
    var bindingForm = BindingForm.State()
  #endif
  var clock = ClockState()
  var counter = Counter.State()
  var dieRoll = DieRollState()
  var effectsBasics = EffectsBasicsState()
  var effectsCancellation = EffectsCancellationState()
  var effectsTimers = TimersState()
  var episodes = EpisodesState(episodes: .mocks)
  #if compiler(>=5.5)
    var focusDemo = FocusDemoState()
  #endif
  var lifecycle = LifecycleDemoState()
  var loadThenNavigate = LoadThenNavigate.State()
  var loadThenNavigateList = LoadThenNavigateList.State()
  var loadThenPresent = LoadThenPresent.State()
  var longLivingEffects = LongLivingEffectsState()
  var map = MapAppState(cityMaps: .mocks)
  var multipleDependencies = MultipleDependenciesState()
  var navigateAndLoad = NavigateAndLoad.State()
  var navigateAndLoadList = NavigateAndLoadList.State()
  var nested = NestedState.mock
  var optionalBasics = OptionalBasics.State()
  var presentAndLoad = PresentAndLoad.State()
  var refreshable = RefreshableState()
  var shared = SharedState()
  var timers = TimersState()
  var twoCounters = TwoCounters.State()
  var webSocket = WebSocketState()
}

enum RootAction {
  case alertAndConfirmationDialog(AlertAndConfirmationDialog.Action)
  case animation(Animations.Action)
  case bindingBasics(BindingBasics.Action)
  #if compiler(>=5.4)
    case bindingForm(BindingForm.Action)
  #endif
  case clock(ClockAction)
  case counter(Counter.Action)
  case dieRoll(DieRollAction)
  case effectsBasics(EffectsBasicsAction)
  case effectsCancellation(EffectsCancellationAction)
  case episodes(EpisodesAction)
  #if compiler(>=5.5)
    case focusDemo(FocusDemoAction)
  #endif
  case lifecycle(LifecycleDemoAction)
  case loadThenNavigate(LoadThenNavigate.Action)
  case loadThenNavigateList(LoadThenNavigateList.Action)
  case loadThenPresent(LoadThenPresent.Action)
  case longLivingEffects(LongLivingEffectsAction)
  case map(MapAppAction)
  case multipleDependencies(MultipleDependenciesAction)
  case navigateAndLoad(NavigateAndLoad.Action)
  case navigateAndLoadList(NavigateAndLoadList.Action)
  case nested(NestedAction)
  case optionalBasics(OptionalBasics.Action)
  case onAppear
  case presentAndLoad(PresentAndLoad.Action)
  case refreshable(RefreshableAction)
  case shared(SharedStateAction)
  case timers(TimersAction)
  case twoCounters(TwoCounters.Action)
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
      Animations()
    }
    Pullback(state: \.bindingBasics, action: /RootAction.bindingBasics) {
      BindingBasics()
    }
    #if compiler(>=5.4)
      Pullback(state: \.bindingForm, action: /RootAction.bindingForm) {
        BindingForm()
      }
    #endif
    Pullback(state: \.clock, action: /RootAction.clock) {
      Reduce(clockReducer, environment: .init(mainQueue: self.mainQueue))
    }
    Pullback(state: \.counter, action: /RootAction.counter) {
      Counter()
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
      LoadThenNavigate()
    }
    Pullback(state: \.loadThenNavigateList, action: /RootAction.loadThenNavigateList) {
      LoadThenNavigateList()
    }
    Pullback(state: \.loadThenPresent, action: /RootAction.loadThenPresent) {
      LoadThenPresent()
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
      NavigateAndLoad()
    }
    Pullback(state: \.navigateAndLoadList, action: /RootAction.navigateAndLoadList) {
      NavigateAndLoadList()
    }
    Pullback(state: \.nested, action: /RootAction.nested) {
      NestedReducer()
    }
    Pullback(state: \.optionalBasics, action: /RootAction.optionalBasics) {
      OptionalBasics()
    }
    Pullback(state: \.presentAndLoad, action: /RootAction.presentAndLoad) {
      PresentAndLoad()
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
      TwoCounters()
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
