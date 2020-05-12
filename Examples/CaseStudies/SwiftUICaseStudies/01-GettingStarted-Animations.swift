import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how changes to application state can drive animations. If you wrap your \
  `viewStore.send` in a `withAnimations` block, then any changes made to state after sending that \
  action will be animated. If you derive a binding from your view store, you can use its \
  `animation` method to animate an action.

  Try it out by tapping anywhere on the screen to move the dot. You can also drag it around the screen.
  """

struct AnimationsState: Equatable {
  var circleCenter = CGPoint.zero
  var isCircleScaled = false
}

enum AnimationsAction: Equatable {
  case circleScaleToggleChanged(Bool)
  case tapped(CGPoint)
}

struct AnimationsEnvironment {}

let animationsReducer = Reducer<AnimationsState, AnimationsAction, AnimationsEnvironment> {
  state, action, environment in

  switch action {
  case let .circleScaleToggleChanged(isScaled):
    state.isCircleScaled = isScaled
    return .none

  case let .tapped(point):
    state.circleCenter = point
    return .none
  }
}

struct AnimationsView: View {
  let store: Store<AnimationsState, AnimationsAction>

  var body: some View {
    GeometryReader { proxy in
      WithViewStore(self.store) { viewStore in
        VStack {
          ZStack(alignment: .center) {
            Text(template: readMe, .body)
              .padding()

            Circle()
              .fill(Color.white)
              .blendMode(.difference)
              .frame(width: 50, height: 50)
              .scaleEffect(viewStore.isCircleScaled ? 2 : 1)
              .offset(
                x: viewStore.circleCenter.x - proxy.size.width / 2,
                y: viewStore.circleCenter.y - proxy.size.height / 2
            )
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.white)
          .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { gesture in
              withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.1)) {
                viewStore.send(.tapped(gesture.location))
              }
            }
          )
          Toggle(
            "Big mode",
            isOn: viewStore
              .binding(
                get: \.isCircleScaled,
                send: AnimationsAction.circleScaleToggleChanged
              )
              .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.1))
          )
            .padding()
        }
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
