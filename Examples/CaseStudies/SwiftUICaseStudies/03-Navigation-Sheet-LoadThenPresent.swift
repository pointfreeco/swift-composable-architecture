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
  case optionalCounter(PresentationAction<CounterAction>)
  case presentDelayCompleted
}

struct LoadThenPresentEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let loadThenPresentReducer =
  Reducer<
    LoadThenPresentState, LoadThenPresentAction, LoadThenPresentEnvironment
  > { state, action, environment in
    switch action {
    case .optionalCounter(.present):
      state.isActivityIndicatorVisible = true
      return Effect(value: .presentDelayCompleted)
        .delay(for: 1, scheduler: environment.mainQueue)
        .eraseToEffect()

    case .optionalCounter:
      return .none

    case .presentDelayCompleted:
      state.isActivityIndicatorVisible = false
      state.optionalCounter = CounterState()
      return .none
    }
  }
  .presents(
    counterReducer,
    state: \.optionalCounter,
    action: /LoadThenPresentAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )

struct LoadThenPresentView: View {
  let store: Store<LoadThenPresentState, LoadThenPresentAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          Button(action: { viewStore.send(.optionalCounter(.present)) }) {
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
        ifLet: store.scope(
          state: \.optionalCounter,
          action: LoadThenPresentAction.optionalCounter
        )
      ) { store in
        NavigationView {
          CounterView(store: store)
            .navigationBarItems(
              trailing: Button(action: { viewStore.send(.optionalCounter(.dismiss)) }) {
                Image(systemName: "xmark")
              }
            )
        }
      }
      .navigationBarTitle("Load and present")
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
