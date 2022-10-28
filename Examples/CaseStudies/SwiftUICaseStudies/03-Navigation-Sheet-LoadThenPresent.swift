import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically presented a sheet that \
  depends on this data.
  """

// MARK: - Feature domain

struct LoadThenPresent: ReducerProtocol {
  struct State: Equatable {
    var optionalCounter: Counter.State?
    var isActivityIndicatorVisible = false

    var isSheetPresented: Bool { self.optionalCounter != nil }
  }

  enum Action {
    case onDisappear
    case optionalCounter(Counter.Action)
    case setSheet(isPresented: Bool)
    case setSheetIsPresentedDelayCompleted
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID {}

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .onDisappear:
        return .cancel(id: CancelID.self)

      case .setSheet(isPresented: true):
        state.isActivityIndicatorVisible = true
        return .task {
          try await self.clock.sleep(for: .seconds(1))
          return .setSheetIsPresentedDelayCompleted
        }
        .cancellable(id: CancelID.self)

      case .setSheet(isPresented: false):
        state.optionalCounter = nil
        return .none

      case .setSheetIsPresentedDelayCompleted:
        state.isActivityIndicatorVisible = false
        state.optionalCounter = Counter.State()
        return .none

      case .optionalCounter:
        return .none
      }
    }
    .ifLet(\.optionalCounter, action: /Action.optionalCounter) {
      Counter()
    }
  }
}

// MARK: - Feature view

struct LoadThenPresentView: View {
  let store: StoreOf<LoadThenPresent>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
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
      .sheet(
        isPresented: viewStore.binding(
          get: \.isSheetPresented,
          send: LoadThenPresent.Action.setSheet(isPresented:)
        )
      ) {
        IfLetStore(
          self.store.scope(
            state: \.optionalCounter,
            action: LoadThenPresent.Action.optionalCounter
          )
        ) {
          CounterView(store: $0)
        }
      }
      .navigationTitle("Load and present")
      .onDisappear { viewStore.send(.onDisappear) }
    }
  }
}

// MARK: - SwiftUI previews

struct LoadThenPresentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenPresentView(
        store: Store(
          initialState: LoadThenPresent.State(),
          reducer: LoadThenPresent()
        )
      )
    }
  }
}
