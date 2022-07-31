import ComposableArchitecture
import SwiftUI

struct SheetDemo: ReducerProtocol {
  struct State: Equatable {
    // TODO: support enum presentation per sheet view modifier
    @PresentationState var animations: Animations.State?
  }

  enum Action: Equatable {
    case animations(PresentationAction<Animations.State, Animations.Action>)
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .animations:
        return .none
      }
    }
    .presents(state: \.$animations, action: /Action.animations) {
      Animations()
    }
  }
}

struct SheetDemoView: View {
  let store: StoreOf<SheetDemo>

  var body: some View {
    WithViewStore(self.store.stateless) { viewStore in
      Button("Present") {
        viewStore.send(.animations(.present(Animations.State())))
      }
    }
    .sheet(
      store: self.store.scope(state: \.$animations, action: SheetDemo.Action.animations),
      content: AnimationsView.init(store:)
    )
  }
}

struct SheetDemo_Previews: PreviewProvider {
  static var previews: some View {
    SheetDemoView(
      store: Store(
        initialState: SheetDemo.State(),
        reducer: SheetDemo()
      )
    )
  }
}
