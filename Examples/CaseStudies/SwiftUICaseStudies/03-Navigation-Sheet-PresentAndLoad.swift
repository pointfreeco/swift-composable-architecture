import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" simultaneously presents a sheet that depends on optional counter \
  state and fires off an effect that will load this state a second later.
  """

struct PresentAndLoadState: Equatable {
  var optionalCounter: CounterState?
  var isSheetPresented = false
}

enum PresentAndLoadAction {
  case optionalCounter(CounterAction)
  case setSheet(isPresented: Bool)
  case setSheetIsPresentedDelayCompleted
}

struct PresentAndLoadEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let presentAndLoadReducer = counterReducer
  .optional
  .pullback(
    state: \.optionalCounter,
    action: /PresentAndLoadAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      PresentAndLoadState, PresentAndLoadAction, PresentAndLoadEnvironment
    > { state, action, environment in
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
    }
  )

struct PresentAndLoadView: View {
  let store: Store<PresentAndLoadState, PresentAndLoadAction>

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
          get: { $0.isSheetPresented },
          send: PresentAndLoadAction.setSheet(isPresented:)
        )
      ) {
        IfLetStore(
          self.store.scope(
            state: { $0.optionalCounter }, action: PresentAndLoadAction.optionalCounter),
          then: CounterView.init(store:),
          else: ActivityIndicator()
        )
      }
      .navigationBarTitle("Present and load")
    }
  }
}

struct PresentAndLoadView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      PresentAndLoadView(
        store: Store(
          initialState: PresentAndLoadState(),
          reducer: presentAndLoadReducer,
          environment: PresentAndLoadEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
  }
}
