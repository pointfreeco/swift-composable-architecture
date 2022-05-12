import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" simultaneously presents a sheet that depends on optional counter \
  state and fires off an effect that will load this state a second later.
  """

struct PresentAndLoad: ReducerProtocol {
  struct State: Equatable {
    var optionalCounter: Counter.State?
    var isSheetPresented = false
  }

  enum Action {
    case optionalCounter(Counter.Action)
    case setSheet(isPresented: Bool)
    case setSheetIsPresentedDelayCompleted
  }

  @Dependency(\.mainQueue) var mainQueue

  var body: some ReducerProtocol<State, Action> {
    Pullback(state: \.optionalCounter, action: /Action.optionalCounter) {
      IfLetReducer {
        Counter()
      }
    }

    Reduce { state, action in
      enum CancelId {}

      switch action {
      case .setSheet(isPresented: true):
        state.isSheetPresented = true
        return Effect(value: .setSheetIsPresentedDelayCompleted)
          .delay(for: 1, scheduler: self.mainQueue)
          .eraseToEffect()
          .cancellable(id: CancelId.self)

      case .setSheet(isPresented: false):
        state.isSheetPresented = false
        state.optionalCounter = nil
        return .cancel(id: CancelId.self)

      case .setSheetIsPresentedDelayCompleted:
        state.optionalCounter = .init()
        return .none

      case .optionalCounter:
        return .none
      }
    }
  }
}

struct PresentAndLoadView: View {
  let store: Store<PresentAndLoad.State, PresentAndLoad.Action>

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
          send: PresentAndLoad.Action.setSheet(isPresented:)
        )
      ) {
        IfLetStore(
          self.store.scope(
            state: \.optionalCounter,
            action: PresentAndLoad.Action.optionalCounter
          ),
          then: CounterView.init(store:),
          else: ProgressView.init
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
          initialState: .init(),
          reducer: PresentAndLoad()
        )
      )
    }
  }
}
