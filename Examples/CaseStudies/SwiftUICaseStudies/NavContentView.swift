import ComposableArchitecture
import SwiftUI

struct ContentState: Equatable {
  var detail: DetailState?
}
enum ContentAction {
  case detail(PresentationAction<DetailAction>)
}

struct DetailState: Equatable {
  var isPaused = false
}
enum DetailAction {
  case setIsPauseActive(Bool)
  case quitButtonTapped
}

let detailReducer = Reducer<DetailState, DetailAction, Void> { state, action, _ in
  switch action {
  case let .setIsPauseActive(isActive):
    state.isPaused = isActive

  default:
    break
  }

  return .none
}

let reducer = Reducer<ContentState, ContentAction, Void> { state, action, _ in
  switch action {
  case .detail(.present):
    state.detail = .init()

  case .detail(.presented(.quitButtonTapped)):
    state.detail = nil

  case .detail:
    break
  }

  return .none
}
.navigates(
  destination: detailReducer,
  tag: /.self,
  selection: \.detail,
  action: /ContentAction.detail,
  environment: { _ in }
)


struct ContentView: View {
  let store: Store<ContentState, ContentAction>

  var body: some View {
    NavigationLinkStore(
      destination: DetailView.init(store:),
      tag: { $0 },
      selection: self.store.scope(state: \.detail, action: ContentAction.detail)
    ) {
      Text("Detail")
    }
  }
}

struct DetailView: View {
  let store: Store<DetailState, DetailAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      NavigationLink(
        "Pause",
        destination: PauseView(onQuit: { viewStore.send(.quitButtonTapped) }),
        isActive: viewStore.binding(get: \.isPaused, send: DetailAction.setIsPauseActive)
      )
    }
  }
}

struct PauseView: View {
  let onQuit: () -> Void

  var body: some View {
    Button(action: self.onQuit) {
      Text("Quit")
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ContentView(
        store: .init(initialState: .init(), reducer: reducer.debugActions(), environment: ())
      )
    }
  }
}
