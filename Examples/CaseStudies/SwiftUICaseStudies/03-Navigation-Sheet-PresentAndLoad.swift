import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" simultaneously presents a sheet that depends on optional counter \
  state and fires off an effect that will load this state a second later.
  """

struct EagerSheetState: Equatable {
  var optionalCounter: CounterState?
  var isSheetPresented = false
}

enum EagerSheetAction {
  case optionalCounter(CounterAction)
  case setSheet(isPresented: Bool)
  case setSheetIsPresentedDelayCompleted
}

struct EagerSheetEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let eagerSheetReducer = Reducer<
  EagerSheetState, EagerSheetAction, EagerSheetEnvironment
>.combine(
  Reducer { state, action, environment in
    switch action {
    case .setSheet(isPresented: true):
      state.isSheetPresented = true
      return Effect(value: .setSheetIsPresentedDelayCompleted)
        .delay(for: 1, scheduler: environment.mainQueue)
        .eraseToEffect()

    case .setSheet(isPresented: false):
      state.isSheetPresented = false
      state.optionalCounter = nil
      return .none

    case .setSheetIsPresentedDelayCompleted:
      state.optionalCounter = CounterState()
      return .none

    case .optionalCounter:
      return .none
    }
  },
  counterReducer.optional.pullback(
    state: \.optionalCounter,
    action: /EagerSheetAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
)

struct EagerSheetView: View {
  let store: Store<EagerSheetState, EagerSheetAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          Button("Load optional counter") {
            viewStore.send(.setSheet(isPresented: true))
          }
        }
      }
      .sheet(
        isPresented: viewStore.binding(
          get: \.isSheetPresented,
          send: EagerSheetAction.setSheet(isPresented:)
        )
      ) {
        IfLetStore(
          self.store.scope(state: \.optionalCounter, action: EagerSheetAction.optionalCounter),
          then: CounterView.init(store:),
          else: ActivityIndicator()
        )
      }
      .navigationBarTitle("Present and load")
    }
  }
}

struct EagerSheetView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      EagerSheetView(
        store: Store(
          initialState: EagerSheetState(),
          reducer: eagerSheetReducer,
          environment: EagerSheetEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
  }
}
