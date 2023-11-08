import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how changes to application state can drive animations. Because the \
  `Store` processes actions sent to it synchronously you can typically perform animations \
  in the Composable Architecture just as you would in regular SwiftUI.

  To animate the changes made to state when an action is sent to the store you can pass along an \
  explicit animation, as well, or you can call `viewStore.send` in a `withAnimation` block.

  To animate changes made to state through a binding, use the `.animation` method on `Binding`.

  To animate asynchronous changes made to state via effects, use `Effect.run` style of effects \
  which allows you to send actions with animations.

  Try it out by tapping or dragging anywhere on the screen to move the dot, and by flipping the \
  toggle at the bottom of the screen.
  """

// MARK: - Feature domain

@Reducer
struct Animations {
  struct State: Equatable {
    @PresentationState var alert: AlertState<Action.Alert>?
    var circleCenter: CGPoint?
    var circleColor = Color.black
    var isCircleScaled = false
  }

  enum Action: Sendable {
    case alert(PresentationAction<Alert>)
    case circleScaleToggleChanged(Bool)
    case rainbowButtonTapped
    case resetButtonTapped
    case setColor(Color)
    case tapped(CGPoint)

    enum Alert: Sendable {
      case resetConfirmationButtonTapped
    }
  }

  @Dependency(\.continuousClock) var clock

  private enum CancelID { case rainbow }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert(.presented(.resetConfirmationButtonTapped)):
        state = State()
        return .cancel(id: CancelID.rainbow)

      case .alert:
        return .none

      case let .circleScaleToggleChanged(isScaled):
        state.isCircleScaled = isScaled
        return .none

      case .rainbowButtonTapped:
        return .run { send in
          for color in [Color.red, .blue, .green, .orange, .pink, .purple, .yellow, .black] {
            await send(.setColor(color), animation: .linear)
            try await self.clock.sleep(for: .seconds(1))
          }
        }
        .cancellable(id: CancelID.rainbow)

      case .resetButtonTapped:
        state.alert = AlertState {
          TextState("Reset state?")
        } actions: {
          ButtonState(
            role: .destructive,
            action: .send(.resetConfirmationButtonTapped, animation: .default)
          ) {
            TextState("Reset")
          }
          ButtonState(role: .cancel) {
            TextState("Cancel")
          }
        }
        return .none

      case let .setColor(color):
        state.circleColor = color
        return .none

      case let .tapped(point):
        state.circleCenter = point
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

// MARK: - Feature view

struct AnimationsView: View {
  @State var store = Store(initialState: Animations.State()) {
    Animations()
  }

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
            .binding(get: \.isCircleScaled, send: { .circleScaleToggleChanged($0) })
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.1))
        )
        .padding()
        Button("Rainbow") { viewStore.send(.rainbowButtonTapped, animation: .linear) }
          .padding([.horizontal, .bottom])
        Button("Reset") { viewStore.send(.resetButtonTapped) }
          .padding([.horizontal, .bottom])
      }
      .alert(store: self.store.scope(state: \.$alert, action: { .alert($0) }))
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

// MARK: - SwiftUI previews

struct AnimationsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        AnimationsView(
          store: Store(initialState: Animations.State()) {
            Animations()
          }
        )
      }

      NavigationView {
        AnimationsView(
          store: Store(initialState: Animations.State()) {
            Animations()
          }
        )
      }
      .environment(\.colorScheme, .dark)
    }
  }
}
