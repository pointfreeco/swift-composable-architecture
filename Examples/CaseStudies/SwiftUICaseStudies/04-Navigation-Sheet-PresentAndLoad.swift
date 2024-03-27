import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" simultaneously presents a sheet that depends on optional counter \
  state and fires off an effect that will load this state a second later.
  """

@Reducer
struct PresentAndLoad {
  @ObservableState
  struct State: Equatable {
    var optionalCounter: Counter.State?
    var isSheetPresented = false
  }

  enum Action {
    case optionalCounter(Counter.Action)
    case setSheet(isPresented: Bool)
    case setSheetIsPresentedDelayCompleted
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID { case load }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .setSheet(isPresented: true):
        state.isSheetPresented = true
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.setSheetIsPresentedDelayCompleted)
        }
        .cancellable(id: CancelID.load)

      case .setSheet(isPresented: false):
        state.isSheetPresented = false
        state.optionalCounter = nil
        return .cancel(id: CancelID.load)

      case .setSheetIsPresentedDelayCompleted:
        state.optionalCounter = Counter.State()
        return .none

      case .optionalCounter:
        return .none
      }
    }
    .ifLet(\.optionalCounter, action: \.optionalCounter) {
      Counter()
    }
  }
}

struct PresentAndLoadView: View {
  @Bindable var store: StoreOf<PresentAndLoad>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      Button("Load optional counter") {
        store.send(.setSheet(isPresented: true))
      }
    }
    .sheet(isPresented: $store.isSheetPresented.sending(\.setSheet)) {
      if let store = store.scope(state: \.optionalCounter, action: \.optionalCounter) {
        CounterView(store: store)
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Present and load")
  }
}

#Preview {
  NavigationView {
    PresentAndLoadView(
      store: Store(initialState: PresentAndLoad.State()) {
        PresentAndLoad()
      }
    )
  }
}
