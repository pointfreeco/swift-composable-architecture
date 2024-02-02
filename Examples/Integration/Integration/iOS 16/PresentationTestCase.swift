@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct PresentationView: View {
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
      store: self.store.scope(
        state: \.$destination.fullScreenCover, action: \.destination.fullScreenCover
      )
    ) { store in
      NavigationStack {
        Form {
          BasicsView(store: store)
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
      store: self.store.scope(state: \.$destination.popover, action: \.destination.popover)
    ) { store in
      NavigationStack {
        Form {
          BasicsView(store: store)
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
    .sheet(store: self.store.scope(state: \.$sheet, action: \.sheet)) { store in
      NavigationStack {
        Form {
          BasicsView(store: store)
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

  @Reducer
  struct Feature {
    struct State: Equatable {
      var isObservingChildCount = false
      @PresentationState var destination: Destination.State?
      @PresentationState var sheet: BasicsView.Feature.State?
    }
    enum Action {
      case destination(PresentationAction<Destination.Action>)
      case dismissButtonTapped
      case presentFullScreenCoverButtonTapped
      case presentPopoverButtonTapped
      case presentSheetButtonTapped
      case sheet(PresentationAction<BasicsView.Feature.Action>)
      case toggleObserveChildCountButtonTapped
    }
    @Reducer
    struct Destination {
      enum State: Equatable {
        case fullScreenCover(BasicsView.Feature.State)
        case popover(BasicsView.Feature.State)
      }
      enum Action {
        case fullScreenCover(BasicsView.Feature.Action)
        case popover(BasicsView.Feature.Action)
      }
      var body: some ReducerOf<Self> {
        Scope(state: \.fullScreenCover, action: \.fullScreenCover) {
          BasicsView.Feature()
        }
        Scope(state: \.popover, action: \.popover) {
          BasicsView.Feature()
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
          state.destination = .fullScreenCover(BasicsView.Feature.State())
          return .none
        case .presentPopoverButtonTapped:
          state.destination = .popover(BasicsView.Feature.State())
          return .none
        case .presentSheetButtonTapped:
          state.sheet = BasicsView.Feature.State()
          return .none
        case .sheet:
          return .none
        case .toggleObserveChildCountButtonTapped:
          state.isObservingChildCount.toggle()
          return .none
        }
      }
      .ifLet(\.$destination, action: \.destination) {
        Destination()
      }
      .ifLet(\.$sheet, action: \.sheet) {
        BasicsView.Feature()
      }
    }
  }
}

#Preview {
  Logger.shared.isEnabled = true
  return PresentationView()
}
