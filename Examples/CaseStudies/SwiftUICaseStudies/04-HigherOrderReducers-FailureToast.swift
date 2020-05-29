import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how the `Reducer` struct can be extended to enhance reducers with extra \
  functionality.

  In it we introduce an `errorHandling` reducer that consumes the failable `appReducer`. \
  It handles the errors by way of a toast, and returns the usual non-failing reducer.

  This form of reducer is useful if you want to centralize and handle failures in the same way. \
  Without this, each routine executed in the `appReducer` would need to handle it's own failure.

  Tapping the "Load Data" button will fail after one second and show a toast.
  """

enum AppError: Error, LocalizedError {
  case api

  var errorDescription: String? { "Whoops! There was a server error." }
}

struct AppState: Equatable {
  var toastState = ToastState()
  var data: [String] = []
}

enum AppAction {
  case toastAction(ToastAction)
  case loadData
  case didLoadData([String])
}

struct AppEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var loadData: () -> Effect<[String], Error>
}

let appReducer: (inout AppState, AppAction, AppEnvironment) -> Effect<AppAction, Error> = { state, action, environment in
  switch action {
  case .toastAction:
    return .none

  case .loadData:
    return environment.loadData().map(AppAction.didLoadData)

  case .didLoadData(let data):
    state.data = data
    return .none
  }
}

extension Reducer {
  static func errorHandling(
    _ reducer: @escaping (inout AppState, AppAction, AppEnvironment) -> Effect<AppAction, Error>
  ) -> Reducer<AppState, AppAction, AppEnvironment> {
    Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
      reducer(&state, action, environment)
        .catch { Just(.toastAction(.show($0.localizedDescription))) }
        .eraseToEffect()
    }
  }
}

struct ToastState: Equatable {
  var status: ToastStatus = .hiding
}

enum ToastStatus: Equatable {
  case showing(String)
  case hiding

  var isShowing: Bool {
      switch self {
      case .showing: return true
      case .hiding: return false
      }
  }

  var text: String {
      switch self {
      case .showing(let text): return text
      case .hiding: return ""
      }
  }
}

enum ToastAction {
  case show(String)
  case hide
}

struct ToastEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let toastReducer = Reducer<ToastState, ToastAction, ToastEnvironment> { state, action, environment in
  switch action {
  case .show(let text):
    state.status = .showing(text)
    return .none

  case .hide:
    state.status = .hiding
    return .none
  }
}

struct ToastView: View {
  let store: Store<ToastState, ToastAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      if viewStore.status.isShowing {
        Text(viewStore.status.text)
          .padding()
          .foregroundColor(.white)
          .background(Color.gray.opacity(0.8))
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { viewStore.send(.hide) }
          }
      }
    }
  }
}

struct DataView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      ZStack(alignment: .bottom) {
        Form {
          Section(header: Text(template: readMe, .caption)) {
            Button("Load Data") { viewStore.send(.loadData) }
            ForEach(viewStore.state.data, id: \.self) { Text($0) }
          }
        }
        ToastView(
          store: self.store.scope(
            state: { $0.toastState },
            action: AppAction.toastAction
          )
        )
      }
      .navigationBarTitle("Failure Toast")
    }
  }
}

let combinedReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  .errorHandling(appReducer),
  toastReducer.pullback(
    state: \AppState.toastState,
    action: /AppAction.toastAction,
    environment: { _ in ToastEnvironment(mainQueue: DispatchQueue.main.eraseToAnyScheduler()) }
  )
)

struct ToastView_Previews: PreviewProvider {
  static var previews: some View {
    DataView(
      store: Store(
        initialState: AppState(),
        reducer: combinedReducer,
        environment: AppEnvironment(
          mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
          loadData: {
            Fail(error: AppError.api)
              .delay(for: 1, scheduler: DispatchQueue.main)
              .eraseToEffect()
          }
        )
      )
    )
  }
}
