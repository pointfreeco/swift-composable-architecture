import ComposableArchitecture
import SwiftUI

private struct EscapedWithViewStoreTestCase: ReducerProtocol {
  enum Action: Equatable, Sendable {
    case incr
    case decr
  }

  func reduce(into state: inout Int, action: Action) -> EffectTask<Action> {
    switch action {
    case .incr:
      state += 1
      return .none
    case .decr:
      state -= 1
      return .none
    }
  }
}

struct EscapedWithViewStoreTestCaseView: View {
  private let store = Store(initialState: 10) {
    EscapedWithViewStoreTestCase()
  }

  var body: some View {
    VStack {
      WithViewStore(store, observe: { $0 }) { viewStore in
        GeometryReader { proxy in
          Text("\(viewStore.state)")
            .accessibilityValue("\(viewStore.state)")
            .accessibilityLabel("EscapedLabel")
        }
        Button("Button", action: { viewStore.send(.incr) })
        Text("\(viewStore.state)")
          .accessibilityValue("\(viewStore.state)")
          .accessibilityLabel("Label")
        Stepper {
          Text("Stepper")
        } onIncrement: {
          viewStore.send(.incr)
        } onDecrement: {
          viewStore.send(.decr)
        }
      }
    }
  }
}
