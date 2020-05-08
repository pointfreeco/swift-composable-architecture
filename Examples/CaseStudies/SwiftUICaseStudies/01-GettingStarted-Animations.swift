import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how changes to application state can drive animations. If you wrap your \
  `viewStore.send` in a `withAnimations` block, then any changes made to state after sending that \
  action will be animated.

  Try it out by tapping anywhere on the screen to move the dot. You can also drag it around the screen.
  """

struct AnimationsState: Equatable {
  var circleCenter = CGPoint.zero
}

enum AnimationsAction: Equatable {
  case tapped(CGPoint)
}

struct AnimationsEnvironment {}

let animationsReducer = Reducer<AnimationsState, AnimationsAction, AnimationsEnvironment> {
  state, action, environment in

  switch action {
  case let .tapped(point):
    state.circleCenter = point
    return .none
  }
}

struct AnimationsView: View {
  let store: Store<AnimationsState, AnimationsAction>

  var body: some View {
    WithViewStore(self.store.stateless) { actionViewStore in
      GeometryReader { proxy in
        ZStack(alignment: .center) {
          Text(template: readMe, .body)
            .padding()

          WithViewStore(self.store.scope(state: \.circleCenter)) { circleCenterViewStore in
            Circle()
              .fill(Color.white)
              .blendMode(.difference)
              .frame(width: 50, height: 50)
              .offset(
                x: circleCenterViewStore.x - proxy.size.width / 2,
                y: circleCenterViewStore.y - proxy.size.height / 2
            )
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .gesture(
          DragGesture(minimumDistance: 0).onChanged { gesture in
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.1)) {
              actionViewStore.send(.tapped(gesture.location))
            }
          }
        )
      }
    }
  }
}

struct AnimationsView_Previews: PreviewProvider {
  static var previews: some View {
    AnimationsView(
      store: Store(
        initialState: AnimationsState(circleCenter: CGPoint(x: 50, y: 50)),
        reducer: animationsReducer,
        environment: AnimationsEnvironment()
      )
    )
  }
}
