@_spi(Logging) import ComposableArchitecture
import Perception
import SwiftUI

struct ObservablePresentationView: View {
  @BindableStore var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
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
          if self.store.isObservingChildCount, let sheetCount = self.store.sheet?.count {
            Text("Count: \(sheetCount)")
          }
        } header: {
          Text("Optional")
        }
      }
      .fullScreenCover(
        item: self.$store.scope(
          state: \.destination?.fullScreenCover,
          action: \.destination.fullScreenCover
        )
      ) { store in
        NavigationStack {
          Form {
            ObservableBasicsView(store: store)
          }
          .navigationTitle("Full-screen cover")
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
        item: self.$store.scope(state: \.destination?.popover, action: \.destination.popover)
      ) { store in
        NavigationStack {
          Form {
            ObservableBasicsView(store: store)
          }
          .navigationTitle("Popover")
          .toolbar {
            ToolbarItem {
              Button("Dismiss") {
                self.store.send(.dismissButtonTapped)
              }
            }
          }
        }
      }
      .sheet(item: self.$store.scope(state: \.sheet, action: \.sheet)) { store in
        NavigationStack {
          Form {
            ObservableBasicsView(store: store)
          }
          .navigationTitle("Sheet")
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
  }

  @Reducer
  struct Feature {
    @ObservableState
    struct State: Equatable {
      var isObservingChildCount = false
      @Presents var destination: Destination.State?
      @Presents var sheet: ObservableBasicsView.Feature.State?
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
    @Reducer
    struct Destination {
      @ObservableState
      enum State: Equatable {
        case fullScreenCover(ObservableBasicsView.Feature.State)
        case popover(ObservableBasicsView.Feature.State)
      }
      enum Action {
        case fullScreenCover(ObservableBasicsView.Feature.Action)
        case popover(ObservableBasicsView.Feature.Action)
      }
      var body: some ReducerOf<Self> {
        Scope(state: \.fullScreenCover, action: \.fullScreenCover) {
          ObservableBasicsView.Feature()
        }
        Scope(state: \.popover, action: \.popover) {
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
      .ifLet(\.$destination, action: \.destination) {
        Destination()
      }
      .ifLet(\.$sheet, action: \.sheet) {
        ObservableBasicsView.Feature()
      }
    }
  }
}
