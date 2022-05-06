import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically presented a sheet that \
  depends on this data.
  """

struct LoadThenPresentState: Equatable {
  var optionalCounter: CounterState?
  var isActivityIndicatorVisible = false

  var isSheetPresented: Bool { self.optionalCounter != nil }
}

enum LoadThenPresentAction {
  case onDisappear
  case optionalCounter(CounterAction)
  case setSheet(isPresented: Bool)
  case setSheetIsPresentedDelayCompleted
}

struct LoadThenPresentEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let loadThenPresentReducer =
  counterReducer
  .optional()
  .pullback(
    state: \.optionalCounter,
    action: /LoadThenPresentAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      LoadThenPresentState, LoadThenPresentAction, LoadThenPresentEnvironment
    > { state, action, environment in

      enum CancelId {}

      switch action {
      case .onDisappear:
        return .cancel(id: CancelId.self)

      case .setSheet(isPresented: true):
        state.isActivityIndicatorVisible = true
        return Effect(value: .setSheetIsPresentedDelayCompleted)
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()
          .cancellable(id: CancelId.self)

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
    }
  )

struct LoadThenPresentView: View {
  let store: Store<LoadThenPresentState, LoadThenPresentAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          Button(action: { viewStore.send(.setSheet(isPresented: true)) }) {
            HStack {
              Text("Load optional counter")
              if viewStore.isActivityIndicatorVisible {
                Spacer()
                ProgressView()
              }
            }
          }
        }
      }
      .sheet(
        isPresented: viewStore.binding(
          get: \.isSheetPresented,
          send: LoadThenPresentAction.setSheet(isPresented:)
        )
      ) {
        IfLetStore(
          self.store.scope(
            state: \.optionalCounter,
            action: LoadThenPresentAction.optionalCounter
          ),
          then: CounterView.init(store:)
        )
      }
      .navigationBarTitle("Load and present")
      .onDisappear { viewStore.send(.onDisappear) }
    }
  }
}

struct LoadThenPresentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenPresentView(
        store: Store(
          initialState: LoadThenPresentState(),
          reducer: loadThenPresentReducer,
          environment: LoadThenPresentEnvironment(
            mainQueue: .main
          )
        )
      )
    }
  }
}
