import ComposableArchitecture
import SwiftUI

private enum PresentationItemTestCase {
  @Reducer
  struct Feature {
    @Reducer
    struct Destination {
      enum State: Equatable {
        case childA(Child.State)
        case childB(Child.State)
      }
      enum Action: Equatable {
        case childA(Child.Action)
        case childB(Child.Action)
      }
      var body: some Reducer<State, Action> {
        Scope(state: \.childA, action: \.childA) {
          Child()
        }
        Scope(state: \.childB, action: \.childB) {
          Child()
        }
      }
    }
    struct State: Equatable {
      @PresentationState var destination: Destination.State?
    }
    enum Action: Equatable {
      case childAButtonTapped
      case childBButtonTapped
      case destination(PresentationAction<Destination.Action>)
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .childAButtonTapped, .destination(.presented(.childB(.swapButtonTapped))):
          state.destination = .childA(Child.State())
          return .none
        case .childBButtonTapped, .destination(.presented(.childA(.swapButtonTapped))):
          state.destination = .childB(Child.State())
          return .none
        case .destination:
          return .none
        }
      }
      .ifLet(\.$destination, action: \.destination) {
        Destination()
      }
    }
  }

  @Reducer
  struct Child {
    struct State: Equatable {}
    enum Action: Equatable {
      case swapButtonTapped
    }
    var body: some ReducerOf<Self> {
      EmptyReducer()
    }
  }
}

struct PresentationItemTestCaseView: View {
  private let store = Store(initialState: PresentationItemTestCase.Feature.State()) {
    PresentationItemTestCase.Feature()
  }

  enum Behavior {
    case sheetStorePlusSwitchStore
    case sheetStores
  }

  @State var behavior: Behavior = .sheetStores

  @ViewBuilder
  var core: some View {
    Button("Child A") {
      self.store.send(.childAButtonTapped)
    }
    Button("Child B") {
      self.store.send(.childBButtonTapped)
    }
  }

  var body: some View {
    switch self.behavior {
    case .sheetStorePlusSwitchStore:
      Button("sheet(store:) + SwitchStore") {
        self.behavior = .sheetStores
      }
      self.core.sheet(
        store: self.store.scope(state: \.$destination, action: \.destination)
      ) { store in
        SwitchStore(store) {
          switch $0 {
          case .childA:
            CaseLet(
              \PresentationItemTestCase.Feature.Destination.State.childA,
              action: PresentationItemTestCase.Feature.Destination.Action.childA
            ) { store in
              Text("Child A")
              Button("Swap") {
                store.send(.swapButtonTapped)
              }
            }
          case .childB:
            CaseLet(
              \PresentationItemTestCase.Feature.Destination.State.childB,
              action: PresentationItemTestCase.Feature.Destination.Action.childB
            ) { store in
              Text("Child B")
              Button("Swap") {
                store.send(.swapButtonTapped)
              }
            }
          }
        }
      }
    case .sheetStores:
      Button("sheet(store:state:action:) + sheet(store:state:action:)") {
        self.behavior = .sheetStorePlusSwitchStore
      }
      self.core
        .sheet(
          store: self.store.scope(state: \.$destination.childA, action: \.destination.childA)
        ) { store in
          Text("Child A")
          Button("Swap") {
            store.send(.swapButtonTapped)
          }
        }
        .sheet(
          store: self.store.scope(state: \.$destination.childB, action: \.destination.childB)
        ) { store in
          Text("Child B")
          Button("Swap") {
            store.send(.swapButtonTapped)
          }
        }
    }
  }
}
