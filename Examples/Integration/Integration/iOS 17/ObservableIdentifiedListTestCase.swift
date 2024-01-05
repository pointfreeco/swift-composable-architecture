@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservableIdentifiedListView: View {
  @Perception.Bindable var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
      List {
        Section {
          if let firstCount = self.store.rows.first?.count {
            HStack {
              Button("Increment First") {
                self.store.send(.incrementFirstButtonTapped)
              }
              Spacer()
              Text("Count: \(firstCount)")
            }
          }
        }
        ForEach(self.store.scope(state: \.rows, action: \.rows)) { store in
          let _ = Logger.shared.log("\(Self.self).body.ForEach")
          Section {
            HStack {
              VStack {
                ObservableBasicsView(store: store)
              }
              Spacer()
              Button(action: { self.store.send(.removeButtonTapped(id: store.state.id)) }) {
                Image(systemName: "trash")
              }
            }
          }
          .buttonStyle(.borderless)
        }
      }
      .toolbar {
        ToolbarItem {
          Button("Add") { self.store.send(.addButtonTapped) }
        }
      }
    }
  }

  @Reducer
  struct Feature {
    @ObservableState
    struct State: Equatable {
      var rows: IdentifiedArrayOf<ObservableBasicsView.Feature.State> = []
    }
    enum Action {
      case addButtonTapped
      case incrementFirstButtonTapped
      case removeButtonTapped(id: ObservableBasicsView.Feature.State.ID)
      case rows(IdentifiedActionOf<ObservableBasicsView.Feature>)
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .addButtonTapped:
          state.rows.append(ObservableBasicsView.Feature.State())
          return .none
        case .incrementFirstButtonTapped:
          state.rows[id: state.rows.ids[0]]?.count += 1
          return .none
        case let .removeButtonTapped(id: id):
          state.rows.remove(id: id)
          return .none
        case .rows:
          return .none
        }
      }
      .forEach(\.rows, action: \.rows) {
        ObservableBasicsView.Feature()
      }
    }
  }
}
