import ComposableArchitecture
import SwiftUI

struct IfLetStoreTestCase: View {
  let store = Store(initialState: Parent.State()) {
    Parent()
  }

  var body: some View {
    Form {
      IfLetStore(
        store.scope(state: \.$child, action: \.child),
        then: ChildView.init(store:),
        else: {
          Button(action: { store.send(.show) }) {
            Text("Show")
          }
        }
      )
    }
  }

  @Reducer
  struct Parent {
    struct State {
      @PresentationState var child: Child.State?
    }
    enum Action {
      case child(PresentationAction<Child.Action>)
      case show
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .child(.presented(.dismiss)):
          state.child = nil
          return .none
        case .child:
          return .none
        case .show:
          state.child = Child.State()
          return .none
        }
      }
      .ifLet(\.$child, action: \.child) {
        Child()
      }
    }
  }
  struct ChildView: View {
    let store: StoreOf<Child>
    var body: some View {
      Button("Dismiss") { store.send(.dismiss) }
    }
  }
  @Reducer
  struct Child {
    struct State {}
    enum Action { case dismiss }
    var body: some ReducerOf<Self> { EmptyReducer() }
  }
}
