import SwiftUI

public struct _ScopeStore<ParentState, ParentAction, ChildState, ChildAction, Content: View>: View {
  final class LazyScopedStore {
    let initialValue: () -> Store<ChildState, ChildAction>
    lazy var store = initialValue()
    init(initialValue: @escaping @autoclosure () -> Store<ChildState, ChildAction>) {
      self.initialValue = initialValue
    }
  }
  //  let scopedStore: Store<ChildState, ChildAction>
  @State var scopedStore: LazyScopedStore
  let content: (Store<ChildState, ChildAction>) -> Content

  init(
    _ store: Store<ParentState, ParentAction>,
    state: @escaping (ParentState) -> ChildState,
    action: @escaping (ChildAction) -> ParentAction,
    @ViewBuilder content: @escaping (Store<ChildState, ChildAction>) -> Content
  ) {
    self._scopedStore = State(wrappedValue: .init(initialValue: store.scope(state: state, action: action)))
    //    self.scopedStore = store.scope(state: state, action: action)
    self.content = content
  }

  public var body: some View {
    self.content(self.scopedStore.store)
  }
}
