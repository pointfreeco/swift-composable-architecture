import ComposableArchitecture
import SwiftUI

struct ForEachBindingTestCase: ReducerProtocol {
  struct State: Equatable {
    var values = ["A", "B", "C"]
  }
  enum Action {
    case change(offset: Int, value: String)
    case removeLast
  }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case let .change(offset: offset, value: value):
      state.values[offset] = value
      return .none

    case .removeLast:
      guard !state.values.isEmpty
      else { return .none }
      state.values.removeLast()
      return .none
    }
  }
}

struct ForEachBindingTestCaseView: View {
  let store: StoreOf<ForEachBindingTestCase>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {  // ⚠️ Must use VStack, not List.
        ForEach(Array(viewStore.values.enumerated()), id: \.offset) { offset, value in
          HStack {  // ⚠️ Must wrap in an HStack.
            TextField(  // ⚠️ Must use a TextField.
              "\(value)",
              text: viewStore.binding(
                get: { $0.values[offset] },
                send: { .change(offset: offset, value: $0) }
              )
            )
          }
        }
      }
      .toolbar {
        ToolbarItem {
          Button("Remove last") {
            viewStore.send(.removeLast)
          }
        }
      }
    }
  }
}
