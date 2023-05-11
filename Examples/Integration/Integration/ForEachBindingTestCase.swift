import ComposableArchitecture
import SwiftUI

private struct ForEachBindingTestCase: ReducerProtocol {
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
  @State var assertion: String?
  private let store = Store(initialState: ForEachBindingTestCase.State()) {
    ForEachBindingTestCase()
  }

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {  // ⚠️ Must use VStack, not List.
        if let assertion = self.assertion {
          Text(assertion)
        }
        ForEach(Array(viewStore.values.enumerated()), id: \.offset) { offset, value in
          HStack {  // ⚠️ Must wrap in an HStack.
            TextField(  // ⚠️ Must use a TextField.
              "\(value)",
              text: viewStore.binding(
                get: {
                  if offset < $0.values.count {
                    return $0.values[offset]
                  } else {
                    DispatchQueue.main.async {
                      self.assertion = "🛑"
                    }
                    return ""
                  }
                },
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
