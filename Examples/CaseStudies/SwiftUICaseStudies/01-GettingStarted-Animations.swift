import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how changes to application state can drive animations. Because the \
  `Store` processes actions sent to it synchronously you can typically perform animations \
  in the Composable Architecture just as you would in regular SwiftUI.

  To animate the changes made to state when an action is sent to the store you only need to wrap \
  instances of `viewStore.send` in a `withAnimations` block. For example, when sending an action \
  to the store when a button is tapped.

  To animate changes made to state through a binding, use the `.animation` method on `Binding`.

  Try it out by tapping or dragging anywhere on the screen to move the dot, and by flipping the \
  toggle at the bottom of the screen.
  """

extension Effect where Failure == Never {
  public static func keyFrames<S>(
    values: [(output: Output, duration: S.SchedulerTimeType.Stride)],
    scheduler: S
  ) -> Effect where S: Scheduler {
    .concatenate(
      values
        .enumerated()
        .map { index, animationState in
          index == 0
            ? Effect(value: animationState.output)
            : Just(animationState.output)
              .delay(for: values[index - 1].duration, scheduler: scheduler)
              .eraseToEffect()
        }
    )
  }
}

struct AnimationsState: Equatable {
  var circleCenter = CGPoint.zero
  var circleColor = Color.white
  var isCircleScaled = false
}

enum AnimationsAction: Equatable {
  case circleScaleToggleChanged(Bool)
  case rainbowButtonTapped
  case setColor(Color)
  case tapped(CGPoint)
}

struct AnimationsEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let animationsReducer = Reducer<AnimationsState, AnimationsAction, AnimationsEnvironment> {
  state, action, environment in

  switch action {
  case let .circleScaleToggleChanged(isScaled):
    state.isCircleScaled = isScaled
    return .none

  case .rainbowButtonTapped:
    return .keyFrames(
      values: [Color.red, .blue, .green, .orange, .pink, .purple, .yellow, .white]
        .map { (output: .setColor($0), duration: 1) },
      scheduler: environment.mainQueue
    )

  case let .setColor(color):
    state.circleColor = color
    return .none

  case let .tapped(point):
    state.circleCenter = point
    return .none
  }
}

struct AnimationsView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<AnimationsState, AnimationsAction>

  var body: some View {
    GeometryReader { proxy in
      WithViewStore(self.store) { viewStore in
        VStack(alignment: .leading) {
          ZStack(alignment: .center) {
            Text(template: readMe, .body)
              .padding()

            Circle()
              .fill(viewStore.circleColor)
              .animation(.linear)
              .blendMode(.difference)
              .frame(width: 50, height: 50)
              .scaleEffect(viewStore.isCircleScaled ? 2 : 1)
              .offset(
                x: viewStore.circleCenter.x - proxy.size.width / 2,
                y: viewStore.circleCenter.y - proxy.size.height / 2
              )
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(self.colorScheme == .dark ? Color.black : .white)
          .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { gesture in
              withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.1)) {
                viewStore.send(.tapped(gesture.location))
              }
            }
          )
          Toggle(
            "Big mode",
            isOn:
              viewStore
              .binding(get: { $0.isCircleScaled }, send: AnimationsAction.circleScaleToggleChanged)
              .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.1))
          )
          .padding()
          Button("Rainbow") { viewStore.send(.rainbowButtonTapped) }
            .padding([.leading, .trailing, .bottom])
        }
      }
    }
  }
}

struct AnimationsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        AnimationsView(
          store: Store(
            initialState: AnimationsState(circleCenter: CGPoint(x: 50, y: 50)),
            reducer: animationsReducer,
            environment: AnimationsEnvironment(
              mainQueue: DispatchQueue.main.eraseToAnyScheduler()
            )
          )
        )
      }

      NavigationView {
        AnimationsView(
          store: Store(
            initialState: AnimationsState(circleCenter: CGPoint(x: 50, y: 50)),
            reducer: animationsReducer,
            environment: AnimationsEnvironment(
              mainQueue: DispatchQueue.main.eraseToAnyScheduler()
            )
          )
        )
      }
      .environment(\.colorScheme, .dark)
    }
  }
}
