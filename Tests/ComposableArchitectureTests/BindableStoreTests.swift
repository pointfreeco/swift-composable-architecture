import Combine
@_spi(Internals) import ComposableArchitecture
import SwiftUI
import XCTest

@MainActor
final class BindableStoreTests: XCTestCase {
  func testBindableStore() {
    struct BindableReducer: Reducer {
      struct State: Equatable {
        @BindingState var something: Int
      }

      enum Action: BindableAction {
        case binding(BindingAction<State>)
      }

      var body: some ReducerOf<Self> {
        BindingReducer()
      }
    }

    struct SomeView_BindableViewState: View {
      let store: StoreOf<BindableReducer>

      struct ViewState: Equatable {
        @BindingViewState var something: Int
      }

      var body: some View {
        WithViewStore(store, observe: { ViewState(something: $0.$something) }) { viewStore in
          EmptyView()
        }
      }
    }

    struct SomeView_BindableViewState_Observed: View {
      let store: StoreOf<BindableReducer>
      @ObservedObject var viewStore: ViewStore<ViewState, BindableReducer.Action>

      struct ViewState: Equatable {
        @BindingViewState var something: Int
      }

      init(store: StoreOf<BindableReducer>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { ViewState(something: $0.$something) })
      }

      var body: some View {
        EmptyView()
      }
    }

    struct SomeView_NoBindableViewState: View {
      let store: StoreOf<BindableReducer>

      struct ViewState: Equatable {}

      var body: some View {
        WithViewStore(store, observe: { _ in ViewState() }) { viewStore in
          EmptyView()
        }
      }
    }

    struct SomeView_NoBindableViewState_Observed: View {
      let store: StoreOf<BindableReducer>
      @ObservedObject var viewStore: ViewStore<ViewState, BindableReducer.Action>

      struct ViewState: Equatable {}

      init(store: StoreOf<BindableReducer>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { _ in ViewState() })
      }

      var body: some View {
        EmptyView()
      }
    }
  }
}
