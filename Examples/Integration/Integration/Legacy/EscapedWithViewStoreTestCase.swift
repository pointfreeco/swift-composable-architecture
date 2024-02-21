import ComposableArchitecture
import SwiftUI

@Reducer
private struct EscapedWithViewStoreTestCase {
  enum Action: Sendable {
    case incr
    case decr
  }

  var body: some Reducer<Int, Action> {
    Reduce { state, action in
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
