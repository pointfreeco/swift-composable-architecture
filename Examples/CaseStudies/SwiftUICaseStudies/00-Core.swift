import ComposableArchitecture

struct Root: ReducerProtocol {
  struct State: Equatable {
    var alertAndConfirmationDialog = AlertAndConfirmationDialog.State()
    var animation = Animations.State()
    var bindingBasics = BindingBasics.State()
    var bindingForm = BindingForm.State()
    var clock = ClockState()
    var counter = Counter.State()
    var effectsBasics = EffectsBasics.State()
    var effectsCancellation = EffectsCancellation.State()
    var episodes = Episodes.State(episodes: .mocks)
    var focusDemo = FocusDemo.State()
    var lifecycle = LifecycleDemo.State()
    var loadThenNavigate = LoadThenNavigate.State()
    var loadThenNavigateList = LoadThenNavigateList.State()
    var loadThenPresent = LoadThenPresent.State()
    var longLivingEffects = LongLivingEffects.State()
    var map = MapApp.State(cityMaps: .mocks)
    var navigateAndLoad = NavigateAndLoad.State()
    var navigateAndLoadList = NavigateAndLoadList.State()
    var navigationStack = NavigationDemo.State()
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
    case bindingForm(BindingForm.Action)
    case clock(ClockAction)
    case counter(Counter.Action)
    case effectsBasics(EffectsBasics.Action)
    case effectsCancellation(EffectsCancellation.Action)
    case episodes(Episodes.Action)
    case focusDemo(FocusDemo.Action)
    case lifecycle(LifecycleDemo.Action)
    case loadThenNavigate(LoadThenNavigate.Action)
    case loadThenNavigateList(LoadThenNavigateList.Action)
    case loadThenPresent(LoadThenPresent.Action)
    case longLivingEffects(LongLivingEffects.Action)
    case map(MapApp.Action)
    case navigateAndLoad(NavigateAndLoad.Action)
    case navigateAndLoadList(NavigateAndLoadList.Action)
    case navigationStack(NavigationDemo.Action)
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

  @Dependency(\.continuousClock) var clock

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state = .init()
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
    Scope(state: \.bindingForm, action: /Action.bindingForm) {
      BindingForm()
    }
    Scope(state: \.clock, action: /Action.clock) {
      Reduce(clockReducer, environment: ClockEnvironment(clock: self.clock))
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
      Episodes(favorite: favorite(id:isFavorite:))
    }
    Scope(state: \.focusDemo, action: /Action.focusDemo) {
      FocusDemo()
    }
    Scope(state: \.lifecycle, action: /Action.lifecycle) {
      LifecycleDemo()
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
      MapApp()
    }
    Scope(state: \.navigateAndLoad, action: /Action.navigateAndLoad) {
      NavigateAndLoad()
    }
    Scope(state: \.navigateAndLoadList, action: /Action.navigateAndLoadList) {
      NavigateAndLoadList()
    }
    Scope(state: \.navigationStack, action: /Action.navigationStack) {
      NavigationDemo()
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
