import ComposableArchitecture

#if canImport(SwiftUI)
  import SwiftUI
#endif

@Reducer fileprivate struct Leaf {}

@Reducer fileprivate enum Inner {
  case leaf(Leaf)
}

@Reducer fileprivate enum Outer {
  case inner(Inner.Body = Inner.body)
}

@Reducer fileprivate struct Parent {
  @ObservableState struct State {
    @Presents var destination: Outer.State?
  }
  enum Action {
    case destination(PresentationAction<Outer.Action>)
  }
  var body: some ReducerOf<Self> {
    EmptyReducer()
      .ifLet(\.$destination, action: \.destination)
  }
}

#if canImport(SwiftUI)
  struct ParentView: View {
    @Bindable fileprivate var store: StoreOf<Parent>

    var body: some View {
      EmptyView()
        .sheet(
          item: $store.scope(state: \.destination, action: \.destination).inner.leaf
        ) { (store: StoreOf<Leaf>) in
          EmptyView()
        }
    }
  }
#endif
