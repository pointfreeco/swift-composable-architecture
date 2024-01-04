import Combine
import ComposableArchitecture
import SwiftUI

@Reducer
struct Row {
  struct State: Equatable, Identifiable {
    var id: Int
  }

  enum Action {
    case task
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .run { _ in
          try await Task.never()
        }
      }
    }
  }
}

@Reducer
struct Feature {
  struct State {
    @PresentationState var child: State?
    var level = 0
    var rows = IdentifiedArray(
      uniqueElements: (0..<500).map { Row.State(id: $0) }
    )
  }

  enum Action {
    indirect case child(PresentationAction<Action>)
    case presentChild
    case rows(IdentifiedActionOf<Row>)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .child:
        return .none
      case .presentChild:
        state.child = State(level: state.level + 1)
        return .publisher { Empty() }.cancellable(id: UUID())
      case .rows:
        return .none
      }
    }
    .ifLet(\.$child, action: \.child) {
      Feature()
    }
    .forEach(\.rows, action: \.rows) {
      Row()
    }
  }
}

struct RowView: View {
  var store: StoreOf<Row>

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Text("Row \(viewStore.id)")
        .task {
          await viewStore.send(.task).finish()
        }
    }
    .id(store.withState(\.id))
  }
}

struct FeatureView: View {
  var store: StoreOf<Feature>

  var body: some View {
    NavigationStack {
      List {
        ForEachStore(store.scope(state: \.rows, action: \.rows)) {
          //        ForEachStore(store.scope(state: \.rows, action: Feature.Action.rows)) {
          RowView(store: $0)
        }
      }
      .toolbar {
        ToolbarItem {
          Button("Child \(store.withState { $0.level + 1 })") {
            store.send(.presentChild)
          }
        }
      }
      .sheet(store: store.scope(state: \.$child, action: \.child)) {
        //      .sheet(store: store.scope(state: \.$child, action: Feature.Action.child)) {
        FeatureView(store: $0)
      }
    }
  }
}
