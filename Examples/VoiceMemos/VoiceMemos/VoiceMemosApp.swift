import ComposableArchitecture
import Foundation
import SwiftUI

@main
struct VoiceMemosApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView(store: .init(initialState: .init(), reducer: TestReducer()))
//      VoiceMemosView(
//        store: Store(
//          initialState: VoiceMemos.State(),
//          reducer: VoiceMemos()._printChanges()
//        )
//      )
    }
  }
}
struct ContentView: View {
  let store: Store<TestReducer.State, TestReducer.Action>
  var body: some View {
      VStack {
        HStack {
          Button("Add") { ViewStore(store).send(.appendNewItem, animation: .default) }
          Button("Del") { ViewStore(store).send(.delLastItem) }
        }
        List {
          ForEachStore(store.scope(state: \.list, action: TestReducer.Action.row)) { store in
            Row(store: store)
          }

          //       Using ForEach(viewState.list) , only the subviews that have changed will be refreshed.
          //                    ForEach(viewStore.list){ item in
          //                        Row1(item: item)
          //                    }
        }
        .task {
          ViewStore(store).send(.onAppear)
        }
    }
  }
}

struct Row: View {
  let store: Store<Item, RowAction>
  var body: some View {
    WithViewStore(store) { item in
      let _ = print("update \(item.id)")
      Text("id:\(item.id),count:\(item.count)")
    }
  }
}

struct Row1: View {
  let item: Item
  var body: some View {
    let _ = print("update \(item.id)")
    Text("id:\(item.id),count:\(item.count)")
  }
}

struct Item:Identifiable,Equatable{
  var id:Int
  var count:Int
}

struct TestReducer:ReducerProtocol {
  struct State:Equatable{
    var list:IdentifiedArrayOf<Item> = []
    var count:Int = 10
  }

  enum Action:Equatable{
    case onAppear
    case appendNewItem
    case delLastItem
    case row(id:Int,action:RowAction)
  }

  var body: some ReducerProtocol<State,Action>{
    Reduce{ state,action in
      switch action{
      case .appendNewItem:
        state.count += 1
        state.list.append(.init(id: state.count, count: state.count))
        return .none
      case .delLastItem:
        state.count -= 1
        state.list.removeLast()
        return .none
      case .onAppear:
        let list = (0...state.count).map{Item(id: $0, count: $0)}
        state.list = IdentifiedArrayOf(uniqueElements: list)
        return .none
      case .row:
        return .none
      }
    }
  }
}

enum RowAction: Equatable {}
