@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservablePresentationView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  struct ViewState: Equatable {
    var sheetCount: Int?
    init(state: Feature.State) {
      self.sheetCount = state.isObservingChildCount ? state.sheet?.count : nil
    }
  }

  var body: some View {
    Form {
      Section {
        Button("Present full-screen cover") {
          self.store.send(.presentFullScreenCoverButtonTapped)
        }
        Button("Present popover") {
          self.store.send(.presentPopoverButtonTapped)
        }
      } header: {
        Text("Enum")
      }
      Section {
        Button("Present sheet") {
          self.store.send(.presentSheetButtonTapped)
        }
        WithViewStore(self.store, observe: ViewState.init) { viewStore in
          let _ = Logger.shared.log("\(Self.self).body")
          if let count = viewStore.sheetCount {
            Text("Count: \(count)")
          }
        }
      } header: {
        Text("Optional")
      }
    }
    .fullScreenCover(
      store: self.store.scope(state: \.$destination, action: { .destination($0) }),
      state: /Feature.Destination.State.fullScreenCover,
      action: { .fullScreenCover($0) }
    ) { store in
      NavigationStack {
        Form {
          ObservableBasicsView(store: store)
        }
        .navigationTitle(Text("Full-screen cover"))
        .toolbar {
          ToolbarItem {
            Button("Dismiss") {
              self.store.send(.dismissButtonTapped)
            }
          }
        }
      }
    }
    .popover(
      store: self.store.scope(state: \.$destination, action: { .destination($0) }),
      state: /Feature.Destination.State.popover,
      action: { .popover($0) }
    ) { store in
      NavigationStack {
        Form {
          ObservableBasicsView(store: store)
        }
        .navigationTitle(Text("Popver"))
        .toolbar {
          ToolbarItem {
            Button("Dismiss") {
              self.store.send(.dismissButtonTapped)
            }
          }
        }
      }
    }
    .sheet(store: self.store.scope(state: \.$sheet, action: { .sheet($0) })) { store in
      NavigationStack {
        Form {
          ObservableBasicsView(store: store)
        }
        .navigationTitle(Text("Sheet"))
        .toolbar {
          ToolbarItem {
            Button("Dismiss") {
              self.store.send(.dismissButtonTapped)
            }
          }
          ToolbarItem(placement: .cancellationAction) {
            Button("Observe child count") {
              self.store.send(.toggleObserveChildCountButtonTapped)
            }
          }
        }
      }
      .presentationDetents([.medium])
    }
  }

  struct Feature: Reducer {
    struct State: Equatable {
      var isObservingChildCount = false
      @PresentationState var destination: Destination.State?
      @PresentationState var sheet: ObservableBasicsView.Feature.State?
    }
    enum Action {
      case destination(PresentationAction<Destination.Action>)
      case dismissButtonTapped
      case presentFullScreenCoverButtonTapped
      case presentPopoverButtonTapped
      case presentSheetButtonTapped
      case sheet(PresentationAction<ObservableBasicsView.Feature.Action>)
      case toggleObserveChildCountButtonTapped
    }
    struct Destination: Reducer {
      enum State: Equatable {
        case fullScreenCover(ObservableBasicsView.Feature.State)
        case popover(ObservableBasicsView.Feature.State)
      }
      enum Action {
        case fullScreenCover(ObservableBasicsView.Feature.Action)
        case popover(ObservableBasicsView.Feature.Action)
      }
      var body: some ReducerOf<Self> {
        Scope(state: /State.fullScreenCover, action: /Action.fullScreenCover) {
          ObservableBasicsView.Feature()
        }
        Scope(state: /State.popover, action: /Action.popover) {
          ObservableBasicsView.Feature()
        }
      }
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .destination:
          return .none
        case .dismissButtonTapped:
          state.destination = nil
          state.sheet = nil
          return .none
        case .presentFullScreenCoverButtonTapped:
          state.destination = .fullScreenCover(ObservableBasicsView.Feature.State())
          return .none
        case .presentPopoverButtonTapped:
          state.destination = .popover(ObservableBasicsView.Feature.State())
          return .none
        case .presentSheetButtonTapped:
          state.sheet = ObservableBasicsView.Feature.State()
          return .none
        case .sheet:
          return .none
        case .toggleObserveChildCountButtonTapped:
          state.isObservingChildCount.toggle()
          return .none
        }
      }
      .ifLet(\.$sheet, action: /Action.sheet) {
        ObservableBasicsView.Feature()
      }
    }
  }
}
