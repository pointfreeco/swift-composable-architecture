import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically presented a sheet that \
  depends on this data.
  """

struct LazySheetState: Equatable {
  var optionalCounter: CounterState?
  var isActivityIndicatorVisible = false

  var isSheetPresented: Bool { self.optionalCounter != nil }
}

enum LazySheetAction {
  case optionalCounter(CounterAction)
  case setSheet(isPresented: Bool)
  case setSheetIsPresentedDelayCompleted
}

struct LazySheetEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let lazySheetReducer = Reducer<
  LazySheetState, LazySheetAction, LazySheetEnvironment
>.combine(
  Reducer { state, action, environment in
    switch action {
    case .setSheet(isPresented: true):
      state.isActivityIndicatorVisible = true
      return Effect(value: .setSheetIsPresentedDelayCompleted)
        .delay(for: 1, scheduler: environment.mainQueue)
        .eraseToEffect()

    case .setSheet(isPresented: false):
      state.optionalCounter = nil
      return .none

    case .setSheetIsPresentedDelayCompleted:
      state.isActivityIndicatorVisible = false
      state.optionalCounter = CounterState()
      return .none

    case .optionalCounter:
      return .none
    }
  },
  counterReducer.optional.pullback(
    state: \.optionalCounter,
    action: /LazySheetAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
)

struct LazySheetView: View {
  let store: Store<LazySheetState, LazySheetAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          Button(action: { viewStore.send(.setSheet(isPresented: true)) }) {
            HStack {
              Text("Load optional counter")
              if viewStore.isActivityIndicatorVisible {
                Spacer()
                ActivityIndicator()
              }
            }
          }
        }
      }
      .sheet(
        isPresented: viewStore.binding(
          get: { $0.isSheetPresented },
          send: LazySheetAction.setSheet(isPresented:)
        )
      ) {
        IfLetStore(
          self.store.scope(state: { $0.optionalCounter }, action: LazySheetAction.optionalCounter),
          then: CounterView.init(store:)
        )
      }
      .navigationBarTitle("Load and present")
    }
  }
}

struct LazySheetView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LazySheetView(
        store: Store(
          initialState: LazySheetState(),
          reducer: lazySheetReducer,
          environment: LazySheetEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
  }
}
