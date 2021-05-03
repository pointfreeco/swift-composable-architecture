//import SwiftUI
//
//extension View {
//  public func sheet<State, Action, Content: View>(
//    store: Store<State?, Action>,
//    dismiss: Action,
//    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
//  ) -> some View {
//    WithViewStore(store.scope(state: { $0 != nil })) { viewStore in
//      self.sheet(
//        isPresented: viewStore.binding(send: dismiss),
//        onDismiss: { viewStore.send(dismiss) },
//        content: {
//          LastNonEmptyView(store, then: content)
//        }
//      )
//    }
//  }
//
//  public func sheet<State, Action, LocalState, LocalAction, Content: View>(
//    store: Store<State, Action>,
//    state: @escaping (State) -> LocalState?,
//    action: @escaping (LocalAction) -> Action,
//    isPresented: @escaping (Bool) -> Action,
//    @ViewBuilder content: @escaping (Store<LocalState, LocalAction>) -> Content
//  ) -> some View {
//    WithViewStore(store.scope(state: { state($0) != nil })) { viewStore in
//      self.sheet(
//        isPresented: viewStore.binding(send: isPresented), // TODO: de-dupe operator on binding?
//        content: {
//          LastNonEmptyView(store.scope(state: state, action: action), then: content)
//        }
//      )
//    }
//  }
//}
//
//private struct LastNonEmptyView<State, Action, Content>: View where Content: View {
//  let content: (ViewStore<State?, Action>) -> Content
//  let store: Store<State?, Action>
//
//  public init<IfContent>(
//    _ store: Store<State?, Action>,
//    @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent
//  ) where Content == _ConditionalContent<IfContent, EmptyView> {
//    self.store = store
//    var lastState: State?
//    self.content = { viewStore in
//      lastState = viewStore.state ?? lastState
//      if let lastState = lastState {
//        return ViewBuilder.buildEither(first: ifContent(store.scope(state: { $0 ?? lastState })))
//      } else {
//        return ViewBuilder.buildEither(second: EmptyView())
//      }
//    }
//  }
//
//  public var body: some View {
//    WithViewStore(
//      self.store,
//      removeDuplicates: { ($0 != nil) == ($1 != nil) },
//      content: self.content
//    )
//  }
//}
