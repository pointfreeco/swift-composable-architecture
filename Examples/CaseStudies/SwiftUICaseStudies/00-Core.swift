import ComposableArchitecture

struct Root: Reducer {
  struct State: Equatable {
    var alertAndConfirmationDialog = AlertAndConfirmationDialog.State()
    var animation = Animations.State()
    var bindingBasics = BindingBasics.State()
    var bindingForm = BindingForm.State()
    var counter = Counter.State()
    var effectsBasics = EffectsBasics.State()
    var effectsCancellation = EffectsCancellation.State()
    var episodes = Episodes.State(episodes: .mocks)
    var focusDemo = FocusDemo.State()
    var loadThenPresent = LoadThenPresent.State()
    var longLivingEffects = LongLivingEffects.State()
    var map = MapApp.State(cityMaps: .mocks)
    var multipleDestinations = MultipleDestinations.State()
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

  @CasePathable
  enum Action {
    case alertAndConfirmationDialog(AlertAndConfirmationDialog.Action)
    case animation(Animations.Action)
    case bindingBasics(BindingBasics.Action)
    case bindingForm(BindingForm.Action)
    case counter(Counter.Action)
    case effectsBasics(EffectsBasics.Action)
    case effectsCancellation(EffectsCancellation.Action)
    case episodes(Episodes.Action)
    case focusDemo(FocusDemo.Action)
    case loadThenPresent(LoadThenPresent.Action)
    case longLivingEffects(LongLivingEffects.Action)
    case map(MapApp.Action)
    case multipleDestinations(MultipleDestinations.Action)
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

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state = .init()
        return .none

      default:
        return .none
      }
    }

    Scope(state: \.alertAndConfirmationDialog, action: \.alertAndConfirmationDialog) {
      AlertAndConfirmationDialog()
    }
    Scope(state: \.animation, action: \.animation) {
      Animations()
    }
    Scope(state: \.bindingBasics, action: \.bindingBasics) {
      BindingBasics()
    }
    Scope(state: \.bindingForm, action: \.bindingForm) {
      BindingForm()
    }
    Scope(state: \.counter, action: \.counter) {
      Counter()
    }
    Scope(state: \.effectsBasics, action: \.effectsBasics) {
      EffectsBasics()
    }
    Scope(state: \.effectsCancellation, action: \.effectsCancellation) {
      EffectsCancellation()
    }
    Scope(state: \.episodes, action: \.episodes) {
      Episodes(favorite: favorite(id:isFavorite:))
    }
    Scope(state: \.focusDemo, action: \.focusDemo) {
      FocusDemo()
    }
    Scope(state: \.loadThenPresent, action: \.loadThenPresent) {
      LoadThenPresent()
    }
    Scope(state: \.longLivingEffects, action: \.longLivingEffects) {
      LongLivingEffects()
    }
    Scope(state: \.map, action: \.map) {
      MapApp()
    }
    Scope(state: \.multipleDestinations, action: \.multipleDestinations) {
      MultipleDestinations()
    }
    Scope(state: \.navigateAndLoad, action: \.navigateAndLoad) {
      NavigateAndLoad()
    }
    Scope(state: \.navigateAndLoadList, action: \.navigateAndLoadList) {
      NavigateAndLoadList()
    }
    Scope(state: \.navigationStack, action: \.navigationStack) {
      NavigationDemo()
    }
    Scope(state: \.nested, action: \.nested) {
      Nested()
    }
    Scope(state: \.optionalBasics, action: \.optionalBasics) {
      OptionalBasics()
    }
    Scope(state: \.presentAndLoad, action: \.presentAndLoad) {
      PresentAndLoad()
    }
    Scope(state: \.refreshable, action: \.refreshable) {
      Refreshable()
    }
    Scope(state: \.shared, action: \.shared) {
      SharedState()
    }
    Scope(state: \.timers, action: \.timers) {
      Timers()
    }
    Scope(state: \.twoCounters, action: \.twoCounters) {
      TwoCounters()
    }
    Scope(state: \.webSocket, action: \.webSocket) {
      WebSocket()
    }
  }
}
