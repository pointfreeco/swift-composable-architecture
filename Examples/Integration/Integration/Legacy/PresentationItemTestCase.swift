import ComposableArchitecture
import SwiftUI

@Reducer
private struct PresentationItemTestCase {
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
private struct Child {
  struct State: Equatable {}
  enum Action: Equatable {
    case swapButtonTapped
  }
  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}

struct PresentationItemTestCaseView: View {
  private let store = Store(initialState: PresentationItemTestCase.State()) {
    PresentationItemTestCase()
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
        store: self.store.scope(state: \.$destination, action: { .destination($0) })
      ) { store in
        SwitchStore(store) {
          switch $0 {
          case .childA:
            CaseLet(
              \PresentationItemTestCase.Destination.State.childA,
              action: PresentationItemTestCase.Destination.Action.childA
            ) { store in
              Text("Child A")
              Button("Swap") {
                store.send(.swapButtonTapped)
              }
            }
          case .childB:
            CaseLet(
              \PresentationItemTestCase.Destination.State.childB,
              action: PresentationItemTestCase.Destination.Action.childB
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
          store: self.store.scope(state: \.$destination, action: { .destination($0) }),
          state: \.childA,
          action: { .childA($0) }
        ) { store in
          Text("Child A")
          Button("Swap") {
            store.send(.swapButtonTapped)
          }
        }
        .sheet(
          store: self.store.scope(state: \.$destination, action: { .destination($0) }),
          state: \.childB,
          action: { .childB($0) }
        ) { store in
          Text("Child B")
          Button("Swap") {
            store.send(.swapButtonTapped)
          }
        }
    }
  }
}
