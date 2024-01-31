@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct IdentifiedListView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  struct ViewState: Equatable {
    var firstCount: Int?
    init(state: Feature.State) {
      self.firstCount = state.rows.first?.count
    }
  }

  var body: some View {
    WithViewStore(self.store, observe: ViewState.init) { viewStore in
      let _ = Logger.shared.log("\(Self.self).body")
      List {
        Section {
          if let firstCount = viewStore.firstCount {
            HStack {
              Button("Increment First") {
                self.store.send(.incrementFirstButtonTapped)
              }
              Spacer()
              Text("Count: \(firstCount)")
            }
          }
        }
        ForEachStore(self.store.scope(state: \.rows, action: \.rows)) { store in
          let _ = Logger.shared.log("\(Self.self).body.ForEachStore")
          let idStore = store.scope(state: \.id, action: \.self)
          WithViewStore(idStore, observe: { $0 }) { viewStore in
            let _ = Logger.shared.log("\(type(of: idStore))")
            Section {
              HStack {
                VStack {
                  BasicsView(store: store)
                }
                Spacer()
                Button(action: { self.store.send(.removeButtonTapped(id: viewStore.state)) }) {
                  Image(systemName: "trash")
                }
              }
            }
            .buttonStyle(.borderless)
          }
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
    struct State: Equatable {
      var rows: IdentifiedArrayOf<BasicsView.Feature.State> = []
    }
    enum Action {
      case addButtonTapped
      case incrementFirstButtonTapped
      case removeButtonTapped(id: BasicsView.Feature.State.ID)
      case rows(IdentifiedActionOf<BasicsView.Feature>)
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .addButtonTapped:
          state.rows.append(BasicsView.Feature.State())
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
        BasicsView.Feature()
      }
    }
  }
}

#Preview {
  Logger.shared.isEnabled = true
  return NavigationStack {
    IdentifiedListView()
  }
}
