import Combine
@_spi(Internals) import ComposableArchitecture
import SwiftUI
import XCTest

@MainActor
final class BindableStoreTests: XCTestCase {
  func testBindableStore() {
    struct BindableReducer: ReducerProtocol {
      struct State: Equatable {
        @BindingState var something: Int
      }

      enum Action: BindableAction {
        case binding(BindingAction<State>)
      }

      var body: some ReducerProtocol<State, Action> {
        BindingReducer()
      }
    }

    struct SomeView: View {
      let store: StoreOf<BindableReducer>

      struct ViewState: Equatable {}

      var body: some View {
        WithViewStore(store, observe: { _ in ViewState() }) { viewStore in
          EmptyView()
        }
      }
    }
  }
}
