import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to programmatically control focus in a tvOS app using the Composable \
  Architecture.

  The current focus can be held in the feature's state, and then the view must listen to changes \
  to that value, via the .onChange view modifier, in order to tell the view's ResetFocusAction \
  to reset its focus.
  """

struct FocusState: Equatable {
  var currentFocus = 1
}

enum FocusAction {
  case randomButtonClicked
}

struct FocusEnvironment {
  var randomElement: () -> Int = { (1..<11).randomElement()! }
}

let focusReducer = Reducer<FocusState, FocusAction, FocusEnvironment> {
  state, action, environment in
  switch action {
  case .randomButtonClicked:
    state.currentFocus = environment.randomElement()
    return .none
  }
}

#if swift(>=5.3)
  @available(tvOS 14.0, *)
  struct FocusView: View {
    let store: Store<FocusState, FocusAction>

    @Environment(\.resetFocus) var resetFocus
    @Namespace private var namespace

    var body: some View {
      WithViewStore(self.store, observe: { $0 }) { viewStore in
        VStack(spacing: 100) {
          Text(readMe)
            .font(.headline)
            .multilineTextAlignment(.leading)
            .padding()

          HStack(spacing: 40) {
            ForEach(1..<6) { index in
              Button(numbers[index]) {}
                .prefersDefaultFocus(viewStore.currentFocus == index, in: self.namespace)
            }
          }
          HStack(spacing: 40) {
            ForEach(6..<11) { index in
              Button(numbers[index]) {}
                .prefersDefaultFocus(viewStore.currentFocus == index, in: self.namespace)
            }
          }

          Button("Focus Random") { viewStore.send(.randomButtonClicked) }
        }
        .onChange(of: viewStore.currentFocus) { _ in
          // Update the view's focus when the state tells us the focus changed.
          self.resetFocus(in: self.namespace)
        }
        .focusScope(self.namespace)
      }
    }
  }

  @available(tvOS 14.0, *)
  struct FocusView_Previews: PreviewProvider {
    static var previews: some View {
      FocusView(
        store: Store(
          initialState: FocusState(),
          reducer: focusReducer,
          environment: FocusEnvironment()
        )
      )
    }
  }
#endif

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
