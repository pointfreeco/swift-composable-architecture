import Combine
import ComposableArchitecture
import SwiftUI

@Reducer
struct Row {
  @ObservableState
  struct State: Equatable, Identifiable {
    let id: Int
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
  @ObservableState
  struct State {
    @Presents var child: State?
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
    .ifLet2(\.child, action: \.child) {
      Feature()
    }
    .forEach2(\.rows, action: \.rows) {
      Row()
    }
  }
}

struct RowView: View {
  var store: StoreOf<Row>

  var body: some View {
    Text("Row \(store.id)")
      .task {
        await store.send(.task).finish()
      }
      .id(store.withState(\.id))
  }
}

struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>

  var body: some View {
    NavigationStack {
      List {
        ForEach(store.scope(state: \.rows, action: \.rows)) {
        //ForEachStore(store.scope(state: \.rows, action: \.rows)) {
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
      .sheet(item: $store.scope(state: \.child, action: \.child)) {
      //.sheet(store: store.scope(state: \.$child, action: \.child)) {
        //      .sheet(store: store.scope(state: \.$child, action: Feature.Action.child)) {
        FeatureView(store: $0)
      }
    }
  }
}
