import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" simultaneously presents a sheet that depends on optional counter \
  state and fires off an effect that will load this state a second later.
  """

// MARK: - Feature domain

@Reducer
struct PresentAndLoad {
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

// MARK: - Feature view

struct PresentAndLoadView: View {
  @State var store = Store(initialState: PresentAndLoad.State()) {
    PresentAndLoad()
  }

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
        Button("Load optional counter") {
          viewStore.send(.setSheet(isPresented: true))
        }
      }
      .sheet(
        isPresented: viewStore.binding(
          get: \.isSheetPresented,
          send: { .setSheet(isPresented: $0) }
        )
      ) {
        IfLetStore(self.store.scope(state: \.optionalCounter, action: { .optionalCounter($0) })) {
          CounterView(store: $0)
        } else: {
          ProgressView()
        }
      }
      .navigationTitle("Present and load")
    }
  }
}

// MARK: - SwiftUI previews

struct PresentAndLoadView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      PresentAndLoadView(
        store: Store(initialState: PresentAndLoad.State()) {
          PresentAndLoad()
        }
      )
    }
  }
}
