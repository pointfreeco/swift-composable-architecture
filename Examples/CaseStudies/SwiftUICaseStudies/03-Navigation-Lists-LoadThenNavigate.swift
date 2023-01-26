import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state from a list element.

  Tapping a row fires off an effect that will load its associated counter state a second later. \
  When the counter state is present, you will be programmatically navigated to the screen that \
  depends on this data.
  """

// MARK: - Feature domain

struct LoadThenNavigateList: ReducerProtocol {
  struct State: Equatable {
    var rows: IdentifiedArrayOf<Row> = [
      Row(count: 1, id: UUID()),
      Row(count: 42, id: UUID()),
      Row(count: 100, id: UUID()),
    ]
    @PresentationStateOf<Counter> var selection

    struct Row: Equatable, Identifiable {
      var count: Int
      let id: UUID
      var isActivityIndicatorVisible = false
    }
  }

  enum Action: Equatable {
    case rowTapped(id: UUID)
    case selection(PresentationActionOf<Counter>)
    case selectionDelayCompleted(UUID)
  }

  @Dependency(\.continuousClock) var clock

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .rowTapped(id):
        enum CancelID {}

        for row in state.rows {
          state.rows[id: row.id]?.isActivityIndicatorVisible = row.id == id
        }
        return .task {
          try await self.clock.sleep(for: .seconds(1))
          return .selectionDelayCompleted(id)
        }
        .cancellable(id: CancelID.self, cancelInFlight: true)

      case .selection:
        return .none

      case let .selectionDelayCompleted(id):
        state.rows[id: id]?.isActivityIndicatorVisible = false
        if let count = state.rows[id: id]?.count {
          state.selection = Counter.State(count: count)
        }
        return .none
      }
    }
    .presentationDestination(\.$selection, action: /Action.selection) {
      Counter()
    }
  }
}

// MARK: - Feature view

struct LoadThenNavigateListView: View {
  let store: StoreOf<LoadThenNavigateList>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
        ForEach(viewStore.rows) { row in
          Button {
            viewStore.send(.rowTapped(id: row.id))
          } label: {
            HStack {
              Text("Load optional counter that starts from \(row.count)")
              if row.isActivityIndicatorVisible {
                Spacer()
                ProgressView()
              }
            }
          } 
        }
      }
      .navigationDestination(
        store: self.store.scope(
          state: \.$selection,
          action: LoadThenNavigateList.Action.selection
        ),
        destination: CounterView.init(store:)
      )
      .navigationTitle("Load then navigate")
    }
  }
}

// MARK: - SwiftUI previews

struct LoadThenNavigateListView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      LoadThenNavigateListView(
        store: Store(
          initialState: LoadThenNavigateList.State(
            rows: [
              LoadThenNavigateList.State.Row(count: 1, id: UUID()),
              LoadThenNavigateList.State.Row(count: 42, id: UUID()),
              LoadThenNavigateList.State.Row(count: 100, id: UUID()),
            ]
          ),
          reducer: LoadThenNavigateList()
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
