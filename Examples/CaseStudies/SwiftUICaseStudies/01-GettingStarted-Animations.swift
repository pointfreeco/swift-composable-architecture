import Combine
import ComposableArchitecture
@preconcurrency import SwiftUI  // NB: SwiftUI.Color and SwiftUI.Animation are not Sendable yet.

private let readMe = """
  This screen demonstrates how changes to application state can drive animations. Because the \
  `Store` processes actions sent to it synchronously you can typically perform animations \
  in the Composable Architecture just as you would in regular SwiftUI.

  To animate the changes made to state when an action is sent to the store you can pass along an \
  explicit animation, as well, or you can call `viewStore.send` in a `withAnimation` block.

  To animate changes made to state through a binding, use the `.animation` method on `Binding`.

  To animate asynchronous changes made to state via effects, use the `.animation` method provided \
  by the CombineSchedulers library to receive asynchronous actions in an animated fashion.

  Try it out by tapping or dragging anywhere on the screen to move the dot, and by flipping the \
  toggle at the bottom of the screen.
  """

struct AnimationsState: Equatable {
  var alert: AlertState<AnimationsAction>?
  var circleCenter: CGPoint?
  var circleColor = Color.black
  var isCircleScaled = false
}

enum AnimationsAction: Equatable, Sendable {
  case alertDismissed
  case circleScaleToggleChanged(Bool)
  case rainbowButtonTapped
  case resetButtonTapped
  case resetConfirmationButtonTapped
  case setColor(Color)
  case tapped(CGPoint)
}

struct AnimationsEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let animationsReducer = Reducer<AnimationsState, AnimationsAction, AnimationsEnvironment> {
  state, action, environment in
  enum CancelID {}

  switch action {
  case .alertDismissed:
    state.alert = nil
    return .none

  case let .circleScaleToggleChanged(isScaled):
    state.isCircleScaled = isScaled
    return .none

  case .rainbowButtonTapped:
    return .run { send in
      for color in [Color.red, .blue, .green, .orange, .pink, .purple, .yellow, .black] {
        await send(.setColor(color), animation: .linear)
        try await environment.mainQueue.sleep(for: 1)
      }
    }
    .cancellable(id: CancelID.self)

  case .resetButtonTapped:
    state.alert = AlertState(
      title: TextState("Reset state?"),
      primaryButton: .destructive(
        TextState("Reset"),
        action: .send(.resetConfirmationButtonTapped, animation: .default)
      ),
      secondaryButton: .cancel(TextState("Cancel"))
    )
    return .none

  case .resetConfirmationButtonTapped:
    state = AnimationsState()
    return .cancel(id: CancelID.self)

  case let .setColor(color):
    state.circleColor = color
    return .none

  case let .tapped(point):
    state.circleCenter = point
    return .none
  }
}

struct AnimationsView: View {
  let store: Store<AnimationsState, AnimationsAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack(alignment: .leading) {
        Text(template: readMe, .body)
          .padding()
          .gesture(
            DragGesture(minimumDistance: 0).onChanged { gesture in
              viewStore.send(
                .tapped(gesture.location),
                animation: .interactiveSpring(response: 0.25, dampingFraction: 0.1)
              )
            }
          )
          .overlay {
            GeometryReader { proxy in
              Circle()
                .fill(viewStore.circleColor)
                .colorInvert()
                .blendMode(.difference)
                .frame(width: 50, height: 50)
                .scaleEffect(viewStore.isCircleScaled ? 2 : 1)
                .position(
                  x: viewStore.circleCenter?.x ?? proxy.size.width / 2,
                  y: viewStore.circleCenter?.y ?? proxy.size.height / 2
                )
                .offset(y: viewStore.circleCenter == nil ? 0 : -44)
            }
            .allowsHitTesting(false)
          }
        Toggle(
          "Big mode",
          isOn:
            viewStore
            .binding(get: \.isCircleScaled, send: AnimationsAction.circleScaleToggleChanged)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.1))
        )
        .padding()
        Button("Rainbow") { viewStore.send(.rainbowButtonTapped, animation: .linear) }
          .padding([.horizontal, .bottom])
        Button("Reset") { viewStore.send(.resetButtonTapped) }
          .padding([.horizontal, .bottom])
      }
      .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

struct AnimationsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        AnimationsView(
          store: Store(
            initialState: AnimationsState(),
            reducer: animationsReducer,
            environment: AnimationsEnvironment(
              mainQueue: .main
            )
          )
        )
      }

      NavigationView {
        AnimationsView(
          store: Store(
            initialState: AnimationsState(),
            reducer: animationsReducer,
            environment: AnimationsEnvironment(
              mainQueue: .main
            )
          )
        )
      }
      .environment(\.colorScheme, .dark)
    }
  }
}
