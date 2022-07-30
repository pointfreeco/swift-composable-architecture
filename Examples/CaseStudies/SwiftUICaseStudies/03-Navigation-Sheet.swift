import ComposableArchitecture
import SwiftUI

enum PresentationAction<Action> {
  case present
  case presented(Action)
  case dismiss
}

extension PresentationAction: Decodable where Action: Decodable {}
extension PresentationAction: Encodable where Action: Encodable {}
extension PresentationAction: Equatable where Action: Equatable {}
extension PresentationAction: Hashable where Action: Hashable {}

extension View {
  func sheet<State, Action, Content>(
    store: Store<State?, PresentationAction<Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View
  where Content: View {
    WithViewStore(store.scope(state: { $0 != nil })) { viewStore in
      self.sheet(isPresented: viewStore.binding(send: { $0 ? .present : .dismiss })) {
        IfLetStore(
          store.scope(state: cachedLastSome { $0 }, action: PresentationAction.presented),
          then: content
        )
      }
    }
  }
}

private func cachedLastSome<A, B>(_ f: @escaping (A) -> B?) -> (A) -> B? {
  var lastWrapped: B?
  return { wrapped in
    lastWrapped = f(wrapped) ?? lastWrapped
    return lastWrapped
  }
}

extension ReducerProtocol {
  func presents<Destination: ReducerProtocol>(
    state: WritableKeyPath<State, Destination.State?>,
    action: CasePath<Action, PresentationAction<Destination.Action>>,
    @ReducerBuilder<Destination.State, Destination.Action> destination: () -> Destination
  ) -> some ReducerProtocol<State, Action> {
    fatalError()
    return EmptyReducer()
  }
}

struct SheetDemo: ReducerProtocol {
  struct State: Equatable {
    var counter: Counter.State?
  }

  enum Action: Equatable {
    case counter(PresentationAction<Counter.Action>)
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .counter(.present):
        state.counter = Counter.State()
        return .none

      case .counter:
        return .none
      }
    }
    .presents(state: \.counter, action: /Action.counter) {
      Counter()
    }
  }
}

struct SheetDemoView: View {
  let store: StoreOf<SheetDemo>

  var body: some View {
    WithViewStore(self.store.stateless) { viewStore in
      Button("Present") {
        viewStore.send(.counter(.present))
      }
    }
    .sheet(
      store: self.store.scope(state: \.counter, action: SheetDemo.Action.counter),
      content: CounterView.init(store:)
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
