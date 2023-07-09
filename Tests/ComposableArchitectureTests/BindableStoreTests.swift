import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest
import SwiftUI

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
      
      var body: some Reducer<State, Action> {
        BindingReducer()
      }
    }
    
    struct SomeView: View {
      let store: StoreOf<BindableReducer>
      
      struct ViewState: Equatable {
        
      }
      
      var body: some View {
        WithViewStore(store, observe: { _ in ViewState() }) { viewstore in // Ambiguous use of 'init(_:observe:content:file:line:)'
          EmptyView()
        }
      }
    }
  }
}
