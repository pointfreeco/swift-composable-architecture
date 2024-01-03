import ComposableArchitecture


@Reducer
struct TimestampApp {
  @ObservableState
  struct State {
    var items: IdentifiedArrayOf<Item>
    @Presents var editItem: EditItem.State?
    @MainActor
    init() {
      @Dependency(\.modelContainer) var modelContainer
      self.items = IdentifiedArray(uniqueElements: try! modelContainer.mainContext.fetch(FetchDescriptor()))
      print(self.items)
    }
  }
  enum Action {
    case addButtonTapped
    case itemTapped(PersistentIdentifier)
    case editItem(PresentationAction<EditItem.Action>)
  }
  @Dependency(\.modelContainer) var modelContainer
  var body: some ReducerOf<Self> {
    // Query(FetchDescription(…))
    /*
     .run {
       for await didChange {
         send(.didChnage)
       }
     }
     */

    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        let item = Item(timestamp: Date())
        modelContainer.mainContext.insert(item)
        //state.items.append(item)
        try! modelContainer.mainContext.save()
        return .none

      case .editItem:
        return .none

      case let .itemTapped(id):
        state.editItem = EditItem.State(itemID: id)
        return .none
      //case .didChange:

      }
    }
    .ifLet(\.$editItem, action: \.editItem) {
      EditItem()
    }

    //.query(…)
  }
}

struct TimestampAppView: View {
  @Bindable var store: StoreOf<TimestampApp>

  var body: some View {
    NavigationSplitView {
      List {
        ForEach(store.items) { item in
          Button {
            store.send(.itemTapped(item.persistentModelID))
          } label: {
            ItemView(item: item)
          }
        }
      }
      .navigationDestination(item: $store.scope(state: \.editItem, action: \.editItem)) { store in
        EditItemView(store: store)
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          EditButton()
        }
        ToolbarItem {
          Button {
            store.send(.addButtonTapped)
          } label: {
            Label("Add Item", systemImage: "plus")
          }
        }
      }
    } detail: {
      Text("Select an item")
    }
  }
}

@Reducer
struct EditItem {
  @ObservableState
  struct State {
    var item: Item
    let scratchContext: ModelContext
    init(itemID: PersistentIdentifier) {
      @Dependency(\.modelContainer) var modelContainer
      self.scratchContext = ModelContext(modelContainer)
      self.scratchContext.autosaveEnabled = false
      self.item = self.scratchContext.model(for: itemID) as! Item
    }
  }
  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case saveButtonTapped
  }
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding(_):
        return .none
      case .saveButtonTapped:
        try! state.scratchContext.save()
        return .none
      }
    }
  }
}

struct EditItemView: View {
  @Bindable var store: StoreOf<EditItem>
  @Environment(\.dismiss) var dismiss

  var body: some View {
    Form {
      Text("Item at \(store.item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
      DatePicker("Date", selection: $store.item.timestamp)
    }
    .toolbar {
      ToolbarItem {
        Button("Save") {
          //try! self.modelContext.save()
          store.send(.saveButtonTapped)
          self.dismiss()
        }
      }
    }
  }
}

struct ItemView: View {
  let item: Item
  init(item: Item) {
    self.item = item
  }
  var body: some View {
    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
  }
}

import Foundation
import SwiftData
import SwiftUI

@Model
final class Item {
  var timestamp: Date

  init(timestamp: Date) {
    self.timestamp = timestamp
  }
}
