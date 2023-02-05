import ComposableArchitecture
@preconcurrency import SwiftUI  // NB: SwiftUI.Color and SwiftUI.Animation are not Sendable yet.

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

struct Animations: ReducerProtocol {
  struct State: Equatable {
    var alert: AlertState<Action>?
    var circleCenter: CGPoint?
    var circleColor = Color.black
    var isCircleScaled = false
  }

  enum Action: Equatable, Sendable {
    case alertDismissed
    case circleScaleToggleChanged(Bool)
    case rainbowButtonTapped
    case resetButtonTapped
    case resetConfirmationButtonTapped
    case setColor(Color)
    case tapped(CGPoint)
  }

  @Dependency(\.continuousClock) var clock

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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
          try await self.clock.sleep(for: .seconds(1))
        }
      }
      .cancellable(id: CancelID.self)

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

    case .resetConfirmationButtonTapped:
      state = State()
      return .cancel(id: CancelID.self)

    case let .setColor(color):
      state.circleColor = color
      return .none

    case let .tapped(point):
      state.circleCenter = point
      return .none
    }
  }
}

// MARK: - Feature view

struct AnimationsView: View {
  let store: StoreOf<Animations>

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
            .binding(get: \.isCircleScaled, send: Animations.Action.circleScaleToggleChanged)
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

// MARK: - SwiftUI previews

struct AnimationsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        AnimationsView(
          store: Store(
            initialState: Animations.State(),
            reducer: Animations()
          )
        )
      }

      NavigationView {
        AnimationsView(
          store: Store(
            initialState: Animations.State(),
            reducer: Animations()
          )
        )
      }
      .environment(\.colorScheme, .dark)
    }
  }
}
