import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how the `Reducer` struct can be extended to enhance reducers with extra \
  functionality.

  In it we introduce an `loadingHandling` reducer that consumes the `appReducer`. \
  It handles showing a loading UI for all actions that opt-in to this behaviour.

  This form of reducer is useful if you want to centralize and handle loading in the same way. \
  Without this, each routine executed in the `appReducer` would need to handle it's own loading UI.

  Tapping the "Load Data" button will show the loading UI and hide it when the call completes.
  """

// MARK: - Loading Domain

struct LoadingState: Equatable {
  var isLoading: Bool = false
}

enum LoadingAction {
  case show
  case hide
}

let loadingReducer = Reducer<LoadingState, LoadingAction, Void> { state, action, _ in
  switch action {
  case .show:
    state.isLoading = true
    return .none

  case .hide:
    state.isLoading = false
    return .none
  }
}

struct LoadingView: View {
  let store: Store<LoadingState, LoadingAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      if viewStore.isLoading {
        Text("Loading...")
          .padding()
          .foregroundColor(.white)
          .background(Color.gray.opacity(0.8))
      }
    }
  }
}

extension Reducer {
  static func loadingHandling(
    _ reducer: Reducer<AppState, AppAction, AppEnvironment>
  ) -> Reducer<AppState, AppAction, AppEnvironment> {
    Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
      if action.shouldShowLoadingUI {
        return reducer(&state, action, environment)
          .prepend(.loadingAction(.show))
          .append(.loadingAction(.hide))
          .eraseToEffect()
      }

      return reducer(&state, action, environment)
    }
  }
}

// MARK - Feature Domain

struct AppState: Equatable {
  var data: [String] = []
  var loadingState = LoadingState()
}

enum AppAction {
  case loadData
  case didLoadData([String])
  case loadingAction(LoadingAction)

  var shouldShowLoadingUI: Bool {
    switch self {
    case .loadData: return true
    default: return false
    }
  }
}

struct AppEnvironment {
  var loadData: () -> Effect<[String], Never>
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  switch action {
  case .loadData:
    return environment.loadData().map(AppAction.didLoadData)

  case .didLoadData(let data):
    state.data = data
    return .none

  case .loadingAction:
    return .none
  }
}

struct AppView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      ZStack {
        Form {
          Section(header: Text(template: readMe, .caption)) {
            Button("Load Data") { viewStore.send(.loadData) }
            ForEach(viewStore.state.data, id: \.self) { Text($0) }
          }
        }
        LoadingView(
          store: self.store.scope(
            state: { $0.loadingState },
            action: AppAction.loadingAction
          )
        )
      }
      .navigationBarTitle("Loading UI")
    }
  }
}

let combinedLoadingReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  .loadingHandling(appReducer),
  loadingReducer.pullback(
    state: \AppState.loadingState,
    action: /AppAction.loadingAction,
    environment: { _ in () }
  )
)

struct LoadingView_Previews: PreviewProvider {
  static var previews: some View {
    AppView(
      store: Store(
        initialState: AppState(),
        reducer: combinedLoadingReducer,
        environment: AppEnvironment(
          loadData: {
            Just(["some data"])
              .delay(for: 1, scheduler: DispatchQueue.main)
              .eraseToEffect()
          }
        )
      )
    )
  }
}
