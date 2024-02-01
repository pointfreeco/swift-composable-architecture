import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to programmatically control focus in a tvOS app using the Composable \
  Architecture.

  The current focus can be held in the feature's state, and then the view must listen to changes \
  to that value, via the .onChange view modifier, in order to tell the view's ResetFocusAction \
  to reset its focus.
  """

@Reducer
struct Focus {
  @ObservableState
  struct State: Equatable {
    var currentFocus = 1
  }

  enum Action {
    case randomButtonClicked
  }

  @Dependency(\.withRandomNumberGenerator) var withRandomNumberGenerator

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .randomButtonClicked:
        state.currentFocus = self.withRandomNumberGenerator {
          (1..<11).randomElement(using: &$0)!
        }
        return .none
      }
    }
  }
}

struct FocusView: View {
  let store: StoreOf<Focus>

  @Environment(\.resetFocus) var resetFocus
  @Namespace private var namespace

  var body: some View {
    VStack(spacing: 100) {
      Text(readMe)
        .font(.headline)
        .multilineTextAlignment(.leading)
        .padding()

      HStack(spacing: 40) {
        ForEach(1..<6) { index in
          Button(numbers[index]) {}
            .prefersDefaultFocus(store.currentFocus == index, in: namespace)
        }
      }
      HStack(spacing: 40) {
        ForEach(6..<11) { index in
          Button(numbers[index]) {}
            .prefersDefaultFocus(store.currentFocus == index, in: namespace)
        }
      }

      Button("Focus Random") { store.send(.randomButtonClicked) }
    }
    .onChange(of: store.currentFocus) {
      // Update the view's focus when the state tells us the focus changed.
      resetFocus(in: namespace)
    }
    .focusScope(namespace)
  }
}

private let numbers = [
  "Zero",
  "One",
  "Two",
  "Three",
  "Four",
  "Five",
  "Six",
  "Seven",
  "Eight",
  "Nine",
  "Ten",
]

#Preview {
  FocusView(
    store: Store(initialState: Focus.State()) {
      Focus()
    }
  )
}
