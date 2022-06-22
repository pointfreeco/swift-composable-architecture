import Combine
import ComposableArchitecture
import UIKit
import XCTestDynamicOverlay

struct Root: ReducerProtocol {
  struct State {
    var alertAndConfirmationDialog = AlertAndConfirmationDialog.State()
    var animation = Animations.State()
    var bindingBasics = BindingBasics.State()
    #if compiler(>=5.4)
      var bindingForm = BindingForm.State()
    #endif
    var clock = ClockState()
    var counter = Counter.State()
    var effectsBasics = EffectsBasics.State()
    var effectsCancellation = EffectsCancellation.State()
    var effectsTimers = Timers.State()
    var episodes = EpisodesState(episodes: .mocks)
    #if compiler(>=5.5)
      var focusDemo = FocusDemo.State()
    #endif
    var lifecycle = LifecycleDemoState()
    var loadThenNavigate = LoadThenNavigate.State()
    var loadThenNavigateList = LoadThenNavigateList.State()
    var loadThenPresent = LoadThenPresent.State()
    var longLivingEffects = LongLivingEffects.State()
    var map = MapAppState(cityMaps: .mocks)
    var multipleDependencies = MultipleDependenciesState()
    var navigateAndLoad = NavigateAndLoad.State()
    var navigateAndLoadList = NavigateAndLoadList.State()
    var nested = Nested.State.mock
    var optionalBasics = OptionalBasics.State()
    var presentAndLoad = PresentAndLoad.State()
    var refreshable = Refreshable.State()
    var shared = SharedState.State()
    var timers = Timers.State()
    var twoCounters = TwoCounters.State()
    var webSocket = WebSocket.State()
  }

  enum Action {
    case alertAndConfirmationDialog(AlertAndConfirmationDialog.Action)
    case animation(Animations.Action)
    case bindingBasics(BindingBasics.Action)
    #if compiler(>=5.4)
      case bindingForm(BindingForm.Action)
    #endif
    case clock(ClockAction)
    case counter(Counter.Action)
    case effectsBasics(EffectsBasics.Action)
    case effectsCancellation(EffectsCancellation.Action)
    case episodes(EpisodesAction)
    #if compiler(>=5.5)
      case focusDemo(FocusDemo.Action)
    #endif
    case lifecycle(LifecycleDemoAction)
    case loadThenNavigate(LoadThenNavigate.Action)
    case loadThenNavigateList(LoadThenNavigateList.Action)
    case loadThenPresent(LoadThenPresent.Action)
    case longLivingEffects(LongLivingEffects.Action)
    case map(MapAppAction)
    case multipleDependencies(MultipleDependenciesAction)
    case navigateAndLoad(NavigateAndLoad.Action)
    case navigateAndLoadList(NavigateAndLoadList.Action)
    case nested(Nested.Action)
    case optionalBasics(OptionalBasics.Action)
    case onAppear
    case presentAndLoad(PresentAndLoad.Action)
    case refreshable(Refreshable.Action)
    case shared(SharedState.Action)
    case timers(Timers.Action)
    case twoCounters(TwoCounters.Action)
    case webSocket(WebSocket.Action)
  }

  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.uuid) var uuid

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state = State()
        return .none

      default:
        return .none
      }
    }

    Scope(state: \.alertAndConfirmationDialog, action: /Action.alertAndConfirmationDialog) {
      AlertAndConfirmationDialog()
    }
    Scope(state: \.animation, action: /Action.animation) {
      Animations()
    }
    Scope(state: \.bindingBasics, action: /Action.bindingBasics) {
      BindingBasics()
    }
    #if compiler(>=5.4)
      Scope(state: \.bindingForm, action: /Action.bindingForm) {
        BindingForm()
      }
    #endif
    Scope(state: \.clock, action: /Action.clock) {
      Reduce(clockReducer, environment: ClockEnvironment(mainQueue: self.mainQueue))
    }
    Scope(state: \.counter, action: /Action.counter) {
      Counter()
    }
    Scope(state: \.effectsBasics, action: /Action.effectsBasics) {
      EffectsBasics()
    }
    Scope(state: \.effectsCancellation, action: /Action.effectsCancellation) {
      EffectsCancellation()
    }
    Scope(state: \.episodes, action: /Action.episodes) {
      Reduce(
        episodesReducer,
        environment: EpisodesEnvironment(favorite: favorite(id:isFavorite:))
      )
    }
    #if compiler(>=5.5)
      Scope(state: \.focusDemo, action: /Action.focusDemo) {
        FocusDemo()
      }
    #endif
    Scope(state: \.lifecycle, action: /Action.lifecycle) {
      Reduce(lifecycleDemoReducer, environment: LifecycleDemoEnvironment(mainQueue: self.mainQueue))
    }
    Scope(state: \.loadThenNavigate, action: /Action.loadThenNavigate) {
      LoadThenNavigate()
    }
    Scope(state: \.loadThenNavigateList, action: /Action.loadThenNavigateList) {
      LoadThenNavigateList()
    }
    Scope(state: \.loadThenPresent, action: /Action.loadThenPresent) {
      LoadThenPresent()
    }
    Scope(state: \.longLivingEffects, action: /Action.longLivingEffects) {
      LongLivingEffects()
    }
    Scope(state: \.map, action: /Action.map) {
      Reduce(
        mapAppReducer,
        environment: MapAppEnvironment(downloadClient: .live, mainQueue: self.mainQueue)
      )
    }
    Scope(state: \.multipleDependencies, action: /Action.multipleDependencies) {
      Reduce(
        multipleDependenciesReducer,
        environment: SystemEnvironment(
          date: { Date() },
          environment: MultipleDependenciesEnvironment(fetchNumber: liveFetchNumber),
          mainQueue: self.mainQueue,
          uuid: { self.uuid() }
        )
      )
    }
    Scope(state: \.navigateAndLoad, action: /Action.navigateAndLoad) {
      NavigateAndLoad()
    }
    Scope(state: \.navigateAndLoadList, action: /Action.navigateAndLoadList) {
      NavigateAndLoadList()
    }
    Scope(state: \.nested, action: /Action.nested) {
      Nested()
    }
    Scope(state: \.optionalBasics, action: /Action.optionalBasics) {
      OptionalBasics()
    }
    Scope(state: \.presentAndLoad, action: /Action.presentAndLoad) {
      PresentAndLoad()
    }
    Scope(state: \.refreshable, action: /Action.refreshable) {
      Refreshable()
    }
    Scope(state: \.shared, action: /Action.shared) {
      SharedState()
    }
    Scope(state: \.timers, action: /Action.timers) {
      Timers()
    }
    Scope(state: \.twoCounters, action: /Action.twoCounters) {
      TwoCounters()
    }
    Scope(state: \.webSocket, action: /Action.webSocket) {
      WebSocket()
    }
  }
}

@Sendable private func liveFetchNumber() async -> Int {
  try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
  return Int.random(in: 1...1_000)
}
